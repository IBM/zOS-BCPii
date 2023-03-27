/* START OF SPECIFICATIONS ********************************************
* Beginning of Copyright and License                                  *
*                                                                     *
* Copyright IBM Corp. 2021, 2023                                      *
*                                                                     *
* Licensed under the Apache License, Version 2.0 (the "License");     *
* you may not use this file except in compliance with the License.    *
* You may obtain a copy of the License at                             *
*                                                                     *
* http://www.apache.org/licenses/LICENSE-2.0                          *
*                                                                     *
* Unless required by applicable law or agreed to in writing,          *
* software distributed under the License is distributed on an         *
* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,        *
* either express or implied.  See the License for the specific        *
* language governing permissions and limitations under the License.   *
*                                                                     *
* End of Copyright and License                                        *
***********************************************************************
*                                                                     *
*    MODULE NAME= HWIRSTC1                                            *
*                                                                     *
*  Sample C code that uses HWIREST API to activate an LPAR.           *
*                                                                     *
*  See the z/OS MVS Programming: Callable Services for                *
*  High-Level Languages publication for more information              *
*  regarding the usage of HWIREST API.                                *
*************************END OF SPECIFICATIONS************************/
#pragma filetag("IBM-1047")    /* compile in EBCDIC */
#pragma csect(code, "HWIRSTC1") /* name of csect */
#pragma longName

#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <iconv.h>
#include <time.h>
#include <sys/time.h>
#include <hwtjic.h> /* JSON interface declaration file  */
#include <hwicic.h> /* BCPii interface declaration file */
#include "hwijprs.h"
#include "hwirstc1.h"

/* set to true for more detailed tracing */
bool verbose2 = false;

/* globals */
char *CPCuri;
char *LPARuri;
char *CPCtargetName;
char *LPARtargetName;

int main(int argc, char **argv)
{
  bool response = false;

  /* The caller is expected to pass in CPC name and LPAR name */
  if (argc == 3)
  {
    for (int i = 1; i < argc; i++)
    {
      printf("argv passed in: %s length %i\n",
             argv[i], strlen(argv[i]));
    }

    /* Create a new parser instance. */
    if (!init_parser())
    {
      printf("Failed to initialize parser\n");
      return -1;
    }

    /* Sets CPCuri and CPCtargetName */
    response = getCPCInfo(argv[1]);

    /* Sets LPARuri and LPARtargetName */
    if (response)
    {
      response = getLPARInfo(argv[2]);
    }

    /* Activate the LPAR */
    if (response)
    {
      response = activateLPAR();
    }

    /* Terminate the parser instance before exiting */
    do_cleanup();
  }
  else
  {
    printf("ERROR: Wrong number of arguments\n");
    printf("USAGE: HWIRSTC1 <CPCname> <LPARname>\n");
  }

  return response;
}

/*
 * Method: getNextActivationProfile
 *
 * Retrieve the current next activation profile name for the LPAR
 * if the information was succesfully returned
 * point the LPARnextActProfile to it's value
 */
bool getNextActivationProfile(char **LPARnextActProfile)
{
  char *responseBody = (char *)malloc(defaultLen15MB);
  char *queryParm = (char *)malloc(defaultLen);

  memset(responseBody, 0, defaultLen15MB);
  memset(queryParm, 0, defaultLen);

  strcpy(queryParm, "?properties=");
  strcat(queryParm, nextActProfile);
  strcat(queryParm, "&");
  strcat(queryParm, cachedAcceptable);

  if (queryLPAR(queryParm, &responseBody, defaultLen15MB))
  {
    if (parse_json_text((char *)responseBody))
    {
      *LPARnextActProfile = find_string(0, (char *)nextActProfile);
      if (*LPARnextActProfile != NULL)
      {
        printf("LPAR %s is %s\n", nextActProfile, *LPARnextActProfile);
        free(responseBody);
        free(queryParm);
        return true;
      }
      else
      {
        printf("ERROR: null returned instead of LPAR activation profile\n");
      }
    }
    else
    {
      printf("ERROR: malformed LPAR activation profile response body\n");
    }
  }

  free(responseBody);
  free(queryParm);

  return false;
}

/*
 * Method: getLPARStatus
 *
 * Retrieve the current status of the LPAR,
 * if the information was succesfully returned
 * point the LPARtatusValue to it's value
 */
bool getLPARStatus(char **LPARstatusValue)
{
  char *responseBody = (char *)malloc(defaultLen15MB);
  char *queryParm = (char *)malloc(defaultLen);

  *LPARstatusValue = NULL;

  memset(responseBody, 0, defaultLen15MB);
  memset(queryParm, 0, defaultLen);

  strcpy(queryParm, "?properties=");
  strcat(queryParm, statusProp);
  strcat(queryParm, "&");
  strcat(queryParm, cachedAcceptable);

  if (queryLPAR(queryParm, &responseBody, defaultLen15MB))
  {
    if (parse_json_text((char *)responseBody))
    {
      *LPARstatusValue = find_string(0, (char *)statusProp);
      if (*LPARstatusValue != NULL)
      {
        printf("LPAR %s is %s\n", statusProp, *LPARstatusValue);
        free(responseBody);
        free(queryParm);
        return true;
      }
      else
      {
        printf("ERROR: null returned instead of LPAR status\n");
      }
    }
    else
    {
      printf("ERROR: malformed LPAR status response body\n");
    }
  }

  free(responseBody);
  free(queryParm);

  return false;
}

/*
 * Method: asyncPost
 *
 * Issue an asynchronous POST operation that on success
 * returns a job-uri which should be used to POLL for
 * the result of the operation.
 *
 * input arguments: uri, target name, request body
 * output arguments: pre-allocated 2048 KB data area for
 *                   the resulting job URI
 */
bool asyncPost(char *uriArg,
               char *targetNameArg,
               char *requestBodyArg,
               char **jobUri)
{
  bool asyncSuccess = false;

  REQUEST_PARM_TYPE request;
  RESPONSE_PARM_TYPE response;

  memset(&request, 0, sizeof(REQUEST_PARM_TYPE));
  memset(&response, 0, sizeof(RESPONSE_PARM_TYPE));

  /* initialize the request first */
  if (uriArg == NULL)
  {
    printf("asyncPost ERROR: missing required uriArg\n");
    return false;
  }
  else if (strlen(uriArg) > defaultLen2K)
  {
    printf("asyncPost ERROR: uriArg length too long\n");
    return false;
  }
  else if (targetNameArg == NULL)
  {
    printf("asyncPost ERROR: missing required targetNameArg\n");
    return false;
  }
  else if (strlen(targetNameArg) > defaultLen)
  {
    printf("asyncPost ERROR: targetNameArg too long\n");
    return false;
  }

  request.uri = uriArg;
  request.uriLen = strlen(uriArg);
  request.httpMethod = HWI_REST_POST;
  request.requestTimeout = 0x00002688;
  request.targetName = targetNameArg;
  request.targetNameLen = strlen(targetNameArg);

  if (requestBodyArg != NULL)
  {
    if (strlen(requestBodyArg) > defaultLen64K)
    {
      printf("asyncPost ERROR: requestBodyArg too long\n");
      return false;
    }
    else
    {
      request.requestBody = requestBodyArg;
      request.requestBodyLen = strlen(requestBodyArg);
    }
  }

  /* now initialize the response parm that will
     be populated with the resulting data
  */
  char *responseBody = (char *)malloc(defaultLen15MB);
  char *responseDate = (char *)malloc(defaultLen);
  char *requestId = (char *)malloc(defaultLen);

  memset(responseBody, 0, defaultLen15MB);
  memset(responseDate, 0, defaultLen);
  memset(requestId, 0, defaultLen);

  response.responseBody = responseBody;
  response.responseBodyLen = defaultLen15MB;
  response.responseDate = responseDate;
  response.responseDateLen = defaultLen;
  response.requestId = requestId;
  response.requestIdLen = defaultLen;

  traceRequest(&request, &response);

  hwirest(
      &request,
      &response);

  /* On success, an async post request returns with
     HTTP Status 202 and a job URI
  */
  if (isSuccessful(&response) &&
      response.httpStatus == 202 &&
      response.responseBodyLen > 0)
  {
    /* Parse the response JSON text. */
    if (parse_json_text((char *)response.responseBody))
    {
      HWTJ_HANDLE_TYPE arrayentry;
      int entryNum = 0;

      entryNum = getnumberOfEntries(0);
      if (entryNum == 1)
      {
        *jobUri = find_string(0, "job-uri");
        if (*jobUri != NULL)
        {
          printf("jobUri:%s\n", *jobUri);
          asyncSuccess = true;
        }
      }
      else
      {
        printf("asyncPost ERROR: empty response body\n");
      }
    }
  }

  free(responseBody);
  free(responseDate);
  free(requestId);

  return asyncSuccess;
}

/*
 * Method: getCPCInfo
 *
 * Issue List CPC Objects operation to retrieve the URI
 * and target name assocaited with the CPC. All subsequent
 * request will build on this information.
 */
bool getCPCInfo(char *CPCname)
{
  bool listSuccess = false;

  REQUEST_PARM_TYPE request;
  RESPONSE_PARM_TYPE response;

  memset(&request, 0, sizeof(REQUEST_PARM_TYPE));
  memset(&response, 0, sizeof(RESPONSE_PARM_TYPE));

  if (CPCname == NULL)
  {
    printf("getCPCInfo ERROR: missing CPC name\n");
    return false;
  }
  else if ((defaultLen2K - strlen(CPCname)) < 0)
  {
    printf("getCPCInfo ERROR: CPC name too long\n");
    return false;
  }

  /* Issue a CPC LIST request to obtain the uri
    and target name associated with CPC named T115:
    GET /api/cpcs?name=<CPCname>

  NOTE: CPC LIST is the only request that does
  not require a target name value because it
  will automatically be sent to the local SE
  */
  char *uri = (char *)malloc(defaultLen2K);
  char *responseBody = (char *)malloc(defaultLen15MB);
  char *responseDate = (char *)malloc(defaultLen);
  char *requestId = (char *)malloc(defaultLen);
  
  memset(uri, 0, defaultLen2K);
  strcpy(uri, "/api/cpcs?name=");
  strncat(uri, CPCname, strlen(CPCname));

  /* initialize all the required input data for the request */
  request.uri = uri;
  request.uriLen = strlen(uri);
  request.httpMethod = HWI_REST_GET;
  request.requestTimeout = 0x00002688;

  /* Initialize the response structure with the address
    and length of the pre-allocated data areas.
    When the service returns, the data areas will contain
    the response value for that specific field and the data area
    length will be updated to reflect the length of that value.
  */
  memset(responseBody, 0, defaultLen15MB);
  memset(responseDate, 0, defaultLen);
  memset(requestId, 0, defaultLen);
  response.responseBody = responseBody;
  response.responseBodyLen = defaultLen15MB;
  response.responseDate = responseDate;
  response.responseDateLen = defaultLen;
  response.requestId = requestId;
  response.requestIdLen = defaultLen;

  traceRequest(&request, &response);

  hwirest(
      &request,
      &response);

  /* An httpStatus in the 200 range indicates the request was successful
  NOTE: A success does not mean the cpc info was returned, 
  the response body may contain an empty cpcs array because
  the SE was not able to match the CPC name or the user ID was
  */
  if (isSuccessful(&response) &&
      response.responseBodyLen > 0)
  {
    /* Parse the response JSON text. */
    if (parse_json_text((char *)response.responseBody))
    {
      HWTJ_HANDLE_TYPE arrayhandle;
      HWTJ_HANDLE_TYPE arrayentry;
      int entryNum = 0;

      arrayhandle = find_array(0, "cpcs");
      if (arrayhandle != NULL)
      {
        entryNum = getnumberOfEntries(arrayhandle);
        if (entryNum == 1)
        {
          arrayentry = getArrayEntry(arrayhandle, 0);
          CPCuri = find_string(arrayentry, "object-uri");
          CPCtargetName = find_string(arrayentry, "target-name");

          if (CPCuri != NULL && CPCtargetName != NULL)
          {
            printf("CPCuri:%s\n", CPCuri);
            printf("CPCtargetName:%s\n", CPCtargetName);
            listSuccess = true;
          }
        }
        else
        {
          printf("getCPCInfo ERROR: empty cpcs array returned, verify authorization\n");
        }
      }
      else
      {
        printf("getCPCInfo ERROR: cpc array not found\n");
      }
    }
  }

  free(uri);
  free(responseBody);
  free(responseDate);
  free(requestId);

  return listSuccess;
}

/*
 * Method: queryLPAR
 *
 * Issue a call to retrieve LPAR properties.
 * All the properties available will be returned unless
 * a query parm argument is provided which woud filter
 * the response content.
 *
 * input arguments: query parameter, if passed in must include the
 *  "?", e.g: "?properties=name"
 *
 * output arguments: pre-allocated response body data area
 *                   and the size of the data area
 */
bool queryLPAR(char *queryParms,
               char **responseBody,
               int responseBodyLen)
{
  bool querySuccess = false;

  REQUEST_PARM_TYPE request;
  RESPONSE_PARM_TYPE response;

  char *uri = (char *)malloc(defaultLen2K);

  memset(&request, 0, sizeof(REQUEST_PARM_TYPE));
  memset(&response, 0, sizeof(RESPONSE_PARM_TYPE));

  memset(uri, 0, defaultLen2K);
  strcpy(uri, LPARuri);

  if (queryParms != NULL)
  {
    if ((strlen(queryParms) + strlen(uri)) < defaultLen2K)
    {
      strcat(uri, queryParms);
    }
    else
    {
      printf("queryLPAR ERROR: queryParms too long\n");
      free(uri);
      return false;
    }
  }

  char *targetName = (char *)malloc(defaultLen);
  char *responseDate = (char *)malloc(defaultLen);
  char *requestId = (char *)malloc(defaultLen);

  memset(targetName, 0, defaultLen);
  strcpy(targetName, LPARtargetName);

  request.httpMethod = HWI_REST_GET;
  request.uri = uri;
  request.uriLen = strlen(uri);
  request.targetName = targetName;
  request.targetNameLen = strlen(targetName);
  request.requestTimeout = 0x00002688;

  memset(responseDate, 0, defaultLen);
  memset(requestId, 0, defaultLen);

  response.responseBody = *responseBody;
  response.responseBodyLen = responseBodyLen;
  response.responseDate = responseDate;
  response.responseDateLen = defaultLen;
  response.requestId = requestId;
  response.requestIdLen = defaultLen;

  traceRequest(&request, &response);

  hwirest(
      &request,
      &response);

  querySuccess = isSuccessful(&response) &&
                 response.httpStatus == 200 &&
                 (response.responseBodyLen > 0);

  free(uri);
  free(targetName);
  free(responseDate);
  free(requestId);

  return querySuccess;
}

/*
 * Method: getLPARInfo
 *
 * Issue List Logical Partitions of CPC operation to retrieve the URI
 * and target name assocaited with the LPAR. All subsequent
 * request will build on this information.
 */
bool getLPARInfo(char *LPARname)
{
  bool listSuccess = false;
  bool parseForUri = false;

  REQUEST_PARM_TYPE request;
  RESPONSE_PARM_TYPE response;

  char *uri = (char *)malloc(defaultLen2K);

  memset(&request, 0, sizeof(REQUEST_PARM_TYPE));
  memset(&response, 0, sizeof(RESPONSE_PARM_TYPE));

  /* create /api/cpcs/{cpc-id}/logical-partitions?name=LPARname */
  memset(uri, 0, defaultLen2K);
  strcpy(uri, CPCuri);

  if (LPARname == NULL)
  {
    printf("getLPARInfo: LPAR name not provided, asking for all\n");
    strcat(uri, "/logical-partitions");
  }
  else if ((defaultLen2K - strlen(LPARname)) < 0)
  {
    printf("getLPARInfo ERROR: LPARname too long\n");
    free(uri);
    return false;
  }
  else
  {
    strcat(uri, "/logical-partitions?name=");
    strncat(uri, LPARname, strlen(LPARname));
    parseForUri = true;
  }
  
  char *targetName = (char *)malloc(defaultLen);
  char *responseBody = (char *)malloc(defaultLen15MB);
  char *responseDate = (char *)malloc(defaultLen);
  char *requestId = (char *)malloc(defaultLen);

  memset(targetName, 0, defaultLen);
  strcpy(targetName, CPCtargetName);

  request.httpMethod = HWI_REST_GET;
  request.uri = uri;
  request.uriLen = strlen(uri);
  request.targetName = targetName;
  request.targetNameLen = strlen(targetName);
  request.requestTimeout = 0x00002688;

  memset(responseBody, 0, defaultLen15MB);
  memset(responseDate, 0, defaultLen);
  memset(requestId, 0, defaultLen);
  response.responseBody = responseBody;
  response.responseBodyLen = defaultLen15MB;
  response.responseDate = responseDate;
  response.responseDateLen = defaultLen;
  response.requestId = requestId;
  response.requestIdLen = defaultLen;

  traceRequest(&request, &response);

  hwirest(
      &request,
      &response);

  if (isSuccessful(&response) && parseForUri &&
      response.responseBodyLen > 0)
  {
    /* Parse the response JSON text. */
    if (parse_json_text((char *)response.responseBody))
    {
      HWTJ_HANDLE_TYPE arrayhandle;
      HWTJ_HANDLE_TYPE arrayentry;
      int entryNum = 0;

      arrayhandle = find_array(0, "logical-partitions");
      if (arrayhandle != NULL)
      {
        entryNum = getnumberOfEntries(arrayhandle);
        if (entryNum == 1)
        {
          arrayentry = getArrayEntry(arrayhandle, 0);
          LPARuri = find_string(arrayentry, "object-uri");
          LPARtargetName = find_string(arrayentry, "target-name");

          if (LPARuri != NULL && LPARtargetName != NULL)
          {
            printf("LPARuri:%s\n", LPARuri);
            printf("LPARtargetName:%s\n", LPARtargetName);
            listSuccess = true;
          }
          else
          {
            printf("getLPARInfo ERROR: failed to located uri and or target name\n");
          }
        }
        else
        {
          printf("getLPARInfo ERROR: empty logical-partitions array returned, verify authorization\n");
        }
      }
      else
      {
        printf("etLPARInfo ERROR: logical-partitions array not found\n");
      }
    }
  }

  free(uri);
  free(targetName);
  free(responseBody);
  free(responseDate);
  free(requestId);

  return listSuccess;
}

/*
 * Method: activateLPAR
 *
 * Activate the LPAR and POLL for it's result.
 * Use the following request body parm for activation:
 *   activation-profile-name = next activation profile
 *   force = true
 *
 * NOTE: an activate will only be attempted if the LPAR
 *       is currently in 'not-activated' state
 */
bool activateLPAR()
{
  bool actionSuccess = false;

  char *LPARstatusValue = NULL;
  char *LPARnextActProfile = NULL;
  char *description = "activate LPAR";

  /* In this scenario, we only want to attempt an activate
     if the current status is 'not-activated'
  */
  if (getLPARStatus(&LPARstatusValue)) {
    if (0 != strcmp(statusLparNotActive,LPARstatusValue)) {
      printf("activateLPAR ERROR:\n");
      printf("LPAR is expected to be in %s status\n", statusLparNotActive);
      printf("LPAR is currently in %s status\n", LPARstatusValue);
      return false;
    }
  }

  char *activateUri = (char *)malloc(defaultLen2K);
  char *requestBody = (char *)malloc(defaultLen64K);

  /*
    To illustrate how a request body is used, re-use the current
     next activation profile for this LPAR as input
  */
  if (getNextActivationProfile(&LPARnextActProfile))
  {
    memset(activateUri, 0, defaultLen2K);
    memset(requestBody, 0, defaultLen64K);

    strcpy(activateUri, LPARuri);
    strcat(activateUri, "/operations/activate");

    strcpy(requestBody, "{");
    strcat(requestBody, "\"activation-profile-name\":\"");
    strcat(requestBody, LPARnextActProfile);
    strcat(requestBody, "\",\"force\":true");
    strcat(requestBody, "}");

    actionSuccess = asyncPostWorker(activateUri, LPARtargetName,
                                    requestBody, description);
  }

  free(activateUri);
  free(requestBody);

  return actionSuccess;
}

/*
 * Method: asyncPostWorker
 *
 * Issues an asynchronous POST operation and then POLLs
 * for it's results. This includes keeping track of
 * how long the actual operations takes.
 *
 * input arguments: uri, target name, request body,
 *                  description of operations
 */
bool asyncPostWorker(char *uriArg,
                     char *targetNameArg,
                     char *requestBodyArg,
                     char *description)
{
  bool actionSuccess = false;

  char *jobStatus;
  char *jobUri = (char *)malloc(defaultLen2K);

  memset(jobUri, 0, defaultLen2K);

  startTimeRecorder();
  if (asyncPost(uriArg, targetNameArg, requestBodyArg, &jobUri))
  {
    pollJobUri(jobUri, targetNameArg, &jobStatus);
    if (0 == strcmp(statusJobComplete, jobStatus))
    {
      actionSuccess = true;
    }
    else
    {
      printf("job failed with final job status of %s\n", jobStatus);
    }
  }
  endTimeRecorder(description);

  return actionSuccess;
}

/*
 * Method: pollJobUri
 *
 * POLLs the job URI every 5 seconds until it's finished
 *
 * input arguments: job uri, target name
 * output arguments: pointer to jobStatus string
 */
void pollJobUri(char *jobUri, char *jobTargetName, char **jobStatus)
{
  *jobStatus = NULL;
  printf("*>>");
  printf("starting polling at %s\n", printTime());
  while (isJobRunning(jobUri, jobTargetName, jobStatus))
  {
    sleep(5); // sleep in seconds
    if (verbose2)
    {
      printf("polling again at %s\n", printTime());
    }
  }
}

/*
 * Method: startTimeRecorded
 *
 * initialize startTimer to the the current time
 */
void startTimeRecorder()
{
  startTimer = 0;
  gettimeofday(&timeDay, NULL);
  startTimer = timeDay.tv_sec;
}

/*
 * Method: endTimeRecorded
 *
 * Display the elapsed time between when
 * the startTimer was set and now.
 */
void endTimeRecorder(char *description)
{
  endTimer = 0;
  gettimeofday(&timeDay, NULL);
  endTimer = timeDay.tv_sec;

  printf("elapsed time for %s completion is %.2f seconds\n",
         description,
         difftime(endTimer, startTimer));
}

/*
 * Method: endTimeRecorded
 *
 * Print the current time.
 */
char *printTime()
{
  gettimeofday(&timeDay, NULL);
  tvSeconds = timeDay.tv_sec;
  localTimeREST = localtime(&tvSeconds);

  return asctime(localTimeREST);
}

/*
 * Method: isJobRunning
 *
 * Retrieve the status of the job associated with the passed in
 * job uri. Return true if the job is still running, has the status
 * of running or cancel-pending. Otherwise return false.
 *
 * input arguments: uri, target name
 * output arguments: pointer to jobStatus string
 */
bool isJobRunning(char *uriArg, char *targetNameArg, char **jobStatus)
{
  REQUEST_PARM_TYPE request;
  RESPONSE_PARM_TYPE response;

  int responseBodyLen = defaultLen15MB;
  char *responseDate = (char *)malloc(defaultLen);
  char *requestId = (char *)malloc(defaultLen);
  char *responseBody = (char *)malloc(responseBodyLen);

  bool jobRunning = false;

  memset(&request, 0, sizeof(REQUEST_PARM_TYPE));
  memset(&response, 0, sizeof(RESPONSE_PARM_TYPE));

  request.httpMethod = HWI_REST_GET;
  request.uri = uriArg;
  request.uriLen = strlen(uriArg);
  request.targetName = targetNameArg;
  request.targetNameLen = strlen(targetNameArg);
  request.requestTimeout = 0x00002688;

  memset(responseBody, 0, responseBodyLen);
  memset(responseDate, 0, defaultLen);
  memset(requestId, 0, defaultLen);

  response.responseBody = responseBody;
  response.responseBodyLen = responseBodyLen;
  response.responseDate = responseDate;
  response.responseDateLen = defaultLen;
  response.requestId = requestId;
  response.requestIdLen = defaultLen;

  if (verbose2)
  {
    traceRequest(&request, &response);
  }

  hwirest(
      &request,
      &response);

  if (response.httpStatus == 200 &&
      response.responseBodyLen > 0)
  {
    /* Parse the response JSON text. */
    if (parse_json_text((char *)response.responseBody))
    {
      *jobStatus = find_string(0, "status");

      if (*jobStatus == NULL)
      {
        printf("Error encountered retrieving status property\n");
      }
      else
      {
        if (verbose2)
        {
          printf("job status is %s\n", **jobStatus);
        }

        if (strncmp(statusJobRunning, *jobStatus,
                    strlen(statusJobRunning)) == 0 ||
            strncmp(statusJobCanPen, *jobStatus,
                    strlen(statusJobCanPen)) == 0)
        {
          jobRunning = true;
        }
      }
    }
  }

  free(responseBody);
  free(responseDate);
  free(requestId);

  return jobRunning;
}

/*
 * Method: printConstTextStr
 *
 * Print out the contents of the constant string if the string
 * length is greater than 0
 */
void printConstTextStr(int len, const char *text, char *description)
{
  char diagTextString[defaultLen15MB];
  if (verbose2)
  {
    printf("* >%sLen: %X (hex), %d (dec)\n",
           description, len, len);
  }

  if (len > 0 && text[0] != '\0')
  {
    memcpy(diagTextString, text, len);
    diagTextString[len] = '\0';
    printf("* >%s:'%s'\n",
           description, diagTextString);
  }
}

/*
 * Method: printTextStr
 *
 * Print out the contents of the string if the string
 * length is greater than 0
 */
void printTextStr(int len,
                  char *text,
                  char *description,
                  char **ptrAddr)
{
  char diagTextString[defaultLen15MB];
  if (verbose2)
  {
    printf("* >%sLen: %X (hex), %d (dec)\n",
           description, len, len);

    printf("* >%s ptraddress: %X (hex)\n",
           description, ptrAddr);
  }

  /************************************************
	 * Clone the diag text area into a buffer which
	 * allows C semantics (null-termination)
	 ***********************************************/
  if (len > 0 && text[0] != '\0')
  {
    memcpy(diagTextString, text, len);
    diagTextString[len] = '\0';
    printf("* >%s:'%s'\n",
           description, diagTextString);
  }
}

/*
 * Method: traceRequest
 *
 * Print out the various request parameters
 */
void traceRequest(REQUEST_PARM_TYPE *pParm, RESPONSE_PARM_TYPE *pParm2)
{
  if (verbose2)
  {
    printf("\n\n*>>REQUEST PARM:\n");
    printf("* >httpMethod: %d (dec)\n",
           pParm->httpMethod);
    printf("* >encoding: %d (dec)\n",
           pParm->encoding);
    printf("* >requestTimeout: %X (hex)\n",
           pParm->requestTimeout);

    printConstTextStr(pParm->requestBodyLen,
                        pParm->requestBody, "requestBody");
    printConstTextStr(pParm->uriLen, pParm->uri, "uri");
    printConstTextStr(pParm->targetNameLen, pParm->targetName, "targetName");
    printConstTextStr(pParm->clientCorrelatorLen, pParm->clientCorrelator,
                      "clientCorrelator");

    printf("\n*>>RESPONSE PARM:\n");
    printf("* >responseDateLen: %d (dec), %X (hex)\n",
           pParm2->responseDateLen, pParm2->responseDateLen);
    printf("* >requestIdLen: %d (dec), %X (hex)\n",
           pParm2->requestIdLen, pParm2->requestIdLen);
    printf("* >responseBodyLen: %d (dec), %X (hex)\n",
           pParm2->responseBodyLen, pParm2->responseBodyLen);
  }
  else
  {
    char *httpMethodStr = (char *)malloc(defaultLen);
    memset(httpMethodStr, 0, defaultLen);
    switch (pParm->httpMethod)
    {
    case HWI_REST_GET:
      strcpy(httpMethodStr, "GET");
      break;
    case HWI_REST_POST:
      strcpy(httpMethodStr, "POST");
      break;
    case HWI_REST_DELETE:
      strcpy(httpMethodStr, "DELETE");
      break;
    default:
      strcpy(httpMethodStr, "Unrecognized");
      break;
    }

    printf("*>>\n");
    printf("*>>REQUEST:\n");
    printf("%s %s\n", httpMethodStr, pParm->uri);
    printConstTextStr(pParm->targetNameLen, pParm->targetName, "targetName");
    printConstTextStr(pParm->clientCorrelatorLen, pParm->clientCorrelator,
                      "clientCorrelator");
    printConstTextStr(pParm->requestBodyLen,
                        pParm->requestBody, "requestBody");
  }
}

/*
 * Method: isSuccessful
 *
 * Return TRUE if the HTTP Status is in the 2xx range,
 * otherwise return FALSE. In addition, trace the corresonding
 * response parameters.
 */
bool isSuccessful(RESPONSE_PARM_TYPE *pParm)
{
  if (pParm->httpStatus > 199 && pParm->httpStatus < 300)
  {
    traceSuccessResponse(pParm);
    return true;
  }
  else
  {
    traceFailureResponse(pParm);
    return false;
  }
}

/*
 * Method: traceSuccessResponse
 *
 * Print out the various response parameters associated
 * with a successful operation
 */
void traceSuccessResponse(RESPONSE_PARM_TYPE *pParm)
{
  printf("*>>\n");
  printf("*>>REQUEST was successful: %d\n", pParm->httpStatus);

  printTextStr(pParm->responseBodyLen,
               (char *)pParm->responseBody, "responseBody",
               (char **)&pParm->responseBody);
  printTextStr(pParm->locationLen, (char *)pParm->location, "location",
                 (char **)&pParm->location);

  if (verbose2)
  {
    printTextStr(pParm->requestIdLen, (char *)pParm->requestId, "requestId",
                 (char **)&pParm->requestId);
    printTextStr(pParm->responseDateLen, (char *)pParm->responseDate, "responseDate",
                 (char **)&pParm->responseDate);
  }
  printf("*>>\n");
}

/*
 * Method: traceFailureResponse
 *
 * Print out the various response parameters associated
 * with a failed operation
 */
void traceFailureResponse(RESPONSE_PARM_TYPE *pParm)
{
  if (pParm->httpStatus < 200 || pParm->httpStatus > 299)
  {
    printf("*>>\n");
    printf("*>>REQUEST failed: %d\n", pParm->httpStatus);

    if (pParm->responseBodyLen > 0)
    {
      if (pParm->responseBodyLen > 1000)
      {
        printf("* >responseBodyLen: %d (dec) %X (hex)\n",
               pParm->responseBodyLen, pParm->responseBodyLen);
      }
      else
      {
        printTextStr(pParm->responseBodyLen,
                     (char *)pParm->responseBody, "responseBody",
                     (char **)&pParm->responseBody);
      }

      if (parse_json_text((char *)pParm->responseBody))
      {
        HWTJ_HANDLE_TYPE arrayentry;
        char *errorMsg;
        int isBCPiiError;

        isBCPiiError = find_boolvalue(0, "bcpii-error");

        if (isBCPiiError == 0)
        {
          printf("bcpii-error is false\n");
        }
        else if (isBCPiiError == 1)
        {
          printf("bcpii-error is true\n");
        }
        else
        {
          printf("bcpii-error not found\n");
        }

        errorMsg = find_string(0, "message");
        if (errorMsg != NULL)
        {
          printf("error: %s\n", errorMsg);
        }
      }
    }

    /* In the case of BCPii flagging the error, if that occurred
       when processing the SE response, then some of the other
       response fields may contain content to tie the 'failed'
       response back to the SE
    */
    printTextStr(pParm->requestIdLen, (char *)pParm->requestId, "requestId",
                 (char **)&pParm->requestId);

    printTextStr(pParm->locationLen, (char *)pParm->location, "location",
                 (char **)&pParm->location);

    printTextStr(pParm->responseDateLen, (char *)pParm->responseDate, "responseDate",
                 (char **)&pParm->responseDate);

    printf("*>>\n");
  }
  else
  {
    printf("error logic, request was good but inside traceFailureResponse\n");
  }
}
