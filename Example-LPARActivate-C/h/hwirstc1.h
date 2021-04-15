/* START OF SPECIFICATIONS *********************************************
 * Beginning of Copyright and License                                  *
 *                                                                     *
 * Copyright 2021 IBM Corp.                                            *
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
 *    HEADER NAME= HWIRSTC1                                            *
 *                                                                     *
 *  Header that contains function declarations and constants used by   *
 *  hwirstc1.cpp                                                       *
 *                                                                     *
 **********************************************************************/
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <hwicic.h>

/**********************************
 * Constants
 *********************************/
static const int defaultLen2K = 2048;
static const int defaultLen64K = 65536;
static const int defaultLen = 256;
static const int defaultLen15MB = 15728640;

/* JOB status will be one of the following values: */
static const char *statusJobRunning = "running";
static const char *statusJobCanPen = "cancel-pending";
static const char *statusJobCanceled = "canceled";
static const char *statusJobComplete = "complete";

/*
LPAR status will be one of the following values:
 "operating" - the logical partition has an active control program
 "not-operating" - the logical partition's CPC is non operational
 "not-activated" - the logical partition does not have an active control program
 "exceptions" - the logical parition's CPC has one ore more unusual conditions
  "acceptable" - indicates all channels are not operations, but
                  their statuses are acceptable
*/
static const char *statusLparOperating = "operating";
static const char *statusLparNotOperating = "not-operating";
static const char *statusLparNotActive = "not-activated";
static const char *statusLparExceptions = "exceptions";
static const char *statusLparAccept = "acceptable";

static const char *nextActProfile = "next-activation-profile-name";
static const char *cachedAcceptable = "cached-acceptable=true";
static const char *statusProp = "status";

struct timeval timeDay;
time_t tvSeconds;
time_t startTimer;
time_t endTimer;

struct tm *localTimeREST;

/**********************************
 * Functions
 *********************************/
bool getNextActivationProfile(char **LPARnextActProfile);
bool getLPARStatus(char **LPARstatusValue);
bool queryLPAR(char *queryParms,
               char **responseBody,
               int responseBodyLen);
bool getCPCInfo(char *CPCname);
bool getLPARInfo(char *LPARname);
bool activateLPAR();
void printConstTextStr(int len, const char *text, char *description);
void pollJobUri(char *jobUri, char *jobTargetName, char **jobStatus);
bool isJobRunning(char *uriArg, char *targetNameArg, char **jobStatus);
bool asyncPost(char *uriArg,
               char *targetNameArg,
               char *requestBodyArg,
               char **jobUri);
bool asyncPostWorker(char *uriArg,
                     char *targetNameArg,
                     char *requestBodyArg,
                     char *description);
bool isSuccessful(RESPONSE_PARM_TYPE *pParm);

/* tracing of request and response */
void traceRequest(REQUEST_PARM_TYPE *pParm,
                  RESPONSE_PARM_TYPE *pParm2);
void traceSuccessResponse(RESPONSE_PARM_TYPE *pParm);
void traceFailureResponse(RESPONSE_PARM_TYPE *pParm);

/* time related */
char* printTime();
void startTimeRecorder();
void endTimeRecorder(char *description);
