 /*REXX*/
 /* START OF SPECIFICATIONS *******************************************/
 /* Beginning of Copyright and License                                */
 /*                                                                   */
 /* Copyright IBM Corp. 2021, 2023                                    */
 /*                                                                   */
 /* Licensed under the Apache License, Version 2.0 (the "License");   */
 /* you may not use this file except in compliance with the License.  */
 /* You may obtain a copy of the License at                           */
 /*                                                                   */
 /* http://www.apache.org/licenses/LICENSE-2.0                        */
 /*                                                                   */
 /* Unless required by applicable law or agreed to in writing,        */
 /* software distributed under the License is distributed on an       */
 /* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,      */
 /* either express or implied.  See the License for the specific      */
 /* language governing permissions and limitations under the License. */
 /*                                                                   */
 /* End of Copyright and License                                      */
 /*-------------------------------------------------------------------*/
 /*                                                                   */
 /*    MODULE NAME: HWIXMRS3                                          */
 /*                                                                   */
 /*    DESCRIPTIVE NAME: Sample REXX code which invokes a command     */
 /*      using the HWIREST service to issue REST API operations.      */
 /*                                                                   */
 /*    FUNCTION:                                                      */
 /*    To be run in a SYSTEM REXX environment, this exec issues an    */
 /*    LPAR ACTIVATE and/or LOAD command via HWIREST.                 */
 /*                                                                   */
 /*    Both ACTIVATE and LOAD produce a synchronous response,         */
 /*    whose body contains a job-uri that uniquely identifies an      */
 /*    an asynchronous phase (job), which is polled for one of the    */
 /*    recognized outcomes:                                           */
 /*        { successful completion, cancellation, failure }           */
 /*                                                                   */
 /*    Polling is done for a user-specified time period, at regular   */
 /*    intervals.  If the initial job status of "running" fails to    */
 /*    change within that time period, the outcome is treated as a    */
 /*    failure.  The polling interval and time period chosen in this  */
 /*    sample are arbitrary and subject to revision by the user.      */
 /*                                                                   */
 /*    HWIREST requests of type GET and POST are made, accordingly,   */
 /*    and the web toolkit's JSON Parser is used to locate essential  */
 /*    attribute values, as needed.  Failures detected at any of      */
 /*    these intermediary processing points abort the exec.           */
 /*                                                                   */
 /*    REQUIRED UPDATES prior to execution:                           */
 /*       ARG_CPC_NAME - CPC associated with the LPAR to load         */
 /*       ARG_LPAR_NAME - LPAR to be loaded                           */
 /*       ARG_LOAD_ADDR - value for the load address                  */
 /*       ARG_LOAD_PARM - value for the load parameter                */
 /*    OPTIONAL UPDATES:                                              */
 /*       POLL_INTERVAL - seconds between poll attempts (default 5)   */
 /*       POLL_TIME_LIMIT - abandon polling if no response            */
 /*                                   (default 10 minutes)            */
 /*    RETURNS:                                                       */
 /*    This exec exits with a completion code of 0 if the LPAR LOAD   */
 /*    was successful. Otherwise, the exec exits with a nonzero       */
 /*    completion.                                                    */
 /*                                                                   */
 /*    DEPENDENCIES:                                                  */
 /*     1. This sample is only supported in System REXX environments  */
 /*        where TSO=YES.                                             */
 /*     2. User running the script requires sufficient                */
 /*        RACF access to facility classes:                           */
 /*          READ access to HWI.TARGET.netid.nau                      */
 /*          CONTROL access to HWI.TARGET.netid.nau.imagename         */
 /*        Where netid.nau represents the 3-to-17 character SNA       */
 /*        name of the particular CPC, and imagename represents the   */
 /*        1-to-8 character LPAR name.  Optionally the * char can be  */
 /*        used instead of imagename to represent all of the LPARs    */
 /*        available on that CPC.                                     */
 /*     3. The activate action assumes an activation profile name     */
 /*        which matches the LPAR name.                               */
 /*                                                                   */
 /*    REFERENCE:                                                     */
 /*        See the z/OS MVS Programming: Callable Services for        */
 /*        High-Level Languages publication for more information      */
 /*        regarding the usage of the BCPii HWIREST service.          */
 /*                                                                   */
 /*********************************************************************/

 /****** UPDATE REQUIRED START -------> */
 ARG_CPC_NAME = ' '
 ARG_LPAR_NAME = ' '
 ARG_LOAD_ADDR = ' '
 ARG_LOAD_PARM = ' '
 /****** UPDATE OPTIONAL START -------> */
 POLL_INTERVAL = 5                    /* 5 second interval */
 POLL_TIME_LIMIT = 10*60              /* abandon after 10 minutes */
 /****** UPDATE ARGS END -------------> */

 Call DefineConstants

 /***********************************************/
 /* MAIN                                        */
 /***********************************************/
 call TraceMessage THIS_EXEC||' starting.'

 ExecStatus = VerifyRequiredArgs()

 If ExecStatus = NO_ERROR Then
   ExecStatus = JSON_getToolkitConstants()

 If ExecStatus = NO_ERROR Then
   ExecStatus = JSON_initParser()

 If ExecStatus = NO_ERROR Then
    ExecStatus = GetCpcUri( ARG_CPC_NAME)

 /* GetLparUri will return:
    NO_ERROR if LPAR is already activated and can be LOADED
    ERROR_NEED_ACTIVATE if an ACTIVATE should be done prior to LOAD
    anything else indicates unexpected error occurred
 */
 If ExecStatus = NO_ERROR Then
    ExecStatus = GetLparUri( ARG_LPAR_NAME )

 /* Attempt to Activate the LPAR and Poll the JOB uri
    for a confirmation of the activate
 */
 If ExecStatus = ERROR_NEED_ACTIVATE Then
   Do
     /* start elapsed time clock */
     Estarttime = TIME('E')
     ExecStatus = IssueLparActivateCommand( LparUri )
     If ExecStatus = NO_ERROR Then
       ExecStatus = PollJobStatus( CommandJobUri,,
                                POLL_INTERVAL,,
                                POLL_TIME_LIMIT )

     /* get elapsed time for activate */
     Eendtime = TIME('R')
     call TraceMessage 'Activate elapsed time(sec): '||Eendtime
   End

 /* Attempt to LOAD the LPAR and POLL the JOB uri
    for a confirmation of the load
 */
 If ExecStatus = NO_ERROR Then
   Do
     /* reset elapsed time clock */
     Estarttime = TIME('E')

     ExecStatus = IssueLparLoadCommand( LparUri )
     If ExecStatus = NO_ERROR Then
       ExecStatus = PollJobStatus( CommandJobUri,,
                                POLL_INTERVAL,,
                                POLL_TIME_LIMIT )
     /* get elapsed time for load */
     Eendtime = TIME('R')
     call TraceMessage 'Load elapsed time(sec): '||Eendtime
   End

 /* Cleanup */
 If isParserInit Then
   call JSON_termParser

 call TraceMessage '  '
 call TraceMessage THIS_EXEC||' ending with completion code:'||ExecStatus

 Exit ExecStatus


 /*******************************************************/
 /* Function:  DefineConstants()                        */
 /*******************************************************/
DefineConstants:

 RUN_ENV = 'AXREXX'

 /* Derived from args via HWIREST GET request(s) */
 CpcUri = ''
 CpcTargetName = ''
 LparUri = ''
 LparTargetName = ''

 /* Derived from HWIREST request response(s) */
 CommandJobUri = ''
 CommandStatus = ''
 JobStatusCode = ''
 JobReasonCode = ''

 /* Json Parser-related */
 ParserHandle = ''
 ResponseJson = ''
 RootHandle = 0

 /*******************************************************/
 /* Names of Json Attributes for which we search in the */
 /* Response Bodies returned by HWIREST.  See the WSAPI */
 /* documentation for name definitions.                 */
 /*******************************************************/
 JSON_ATTR_CPCS = 'cpcs'
 JSON_ATTR_JOBREASONCODE = 'job-reason-code'
 JSON_ATTR_JOBSTATUSCODE = 'job-status-code'
 JSON_ATTR_JOBURI = 'job-uri'
 JSON_ATTR_LOGICAL_PARTITIONS = 'logical-partitions'
 JSON_ATTR_OBJECTURI = 'object-uri'
 JSON_ATTR_STATUS = 'status'
 JSON_ATTR_TARGETNAME = 'target-name'
 JSON_ATTR_ERRMSG = 'message'
 JSON_ATTR_BCPIIERR = 'bcpii-error'

 /*****************************************************/
 /* Possible status values for the Lpar for which we  */
 /* will issue the load command.  See the WSAPI       */
 /* documentation for more value definitions.         */
 /*****************************************************/
 LPAR_STATUS_NOT_ACTIVATED = 'not-activated'
 LPAR_STATUS_NOT_OPERATING = 'not-operating'
 LPAR_STATUS_OPERATING = 'operating'
 LPAR_STATUS_EXCEPTIONS = 'exceptions'
 LPAR_STATUS_ACCEPTABLE = 'acceptable'

 /*******************************************************/
 /* Possible status values for the async phase of the   */
 /* Lpar load command which we issue.  See the WSAPI    */
 /* documentation for more value definitions.           */
 /*******************************************************/
 JOB_STATUS_CANCELED = 'canceled'
 JOB_STATUS_CANCEL_PENDING = 'cancel-pending'
 JOB_STATUS_COMPLETE = 'complete'
 JOB_STATUS_RUNNING = 'running'

 /* HWIREST request globals */
 HwirestRequestStatus = ''
 ExpectedHttpStatus = ''
 HTTP_STATUS_OK = 200
 HTTP_STATUS_ACCEPTED = 202
 HWI_REST_POST   = 1
 HWI_REST_GET    = 2
 HWI_REST_PUT    = 3
 HWI_REST_DELETE = 4

 /* General purpose globals */
 ExecStatus = '0'
 RexxRC = '0'
 Verbose = '0'                    /* change for additional trace */

 /* Misc Constants */
 THIS_EXEC = 'HWIXMRS3'
 HWIREST_MAXIMAL_TIMEOUT = 0    /* indicates use default 60 minutes */
 isParserInit = '0'

 /***********************************************/
 /* Constants for ExecStatus, to help identify  */
 /* any point of failure within this exec.      */
 /***********************************************/
 NO_ERROR = 0
 ERROR_BASE = 1000
 ERROR_ARGS = ERROR_BASE + 1
 ERROR_TOOLKIT_CONSTANTS = ERROR_BASE + 2
 ERROR_PARSER_INIT = ERROR_BASE + 3
 ERROR_REXXENV = ERROR_BASE + 4
 ERROR_GET_CPC_INFO = ERROR_BASE + 5
 ERROR_GET_LPAR_INFO = ERROR_BASE + 6
 ERROR_POST_LOAD_COMMAND = ERROR_BASE + 7
 ERROR_POLL = ERROR_BASE + 8
 ERROR_GET_JOB_STATUS = ERROR_BASE + 9
 ERROR_GET_JOB_RESULT = ERROR_BASE + 10
 ERROR_PARSER = ERROR_BASE + 11
 ERROR_NEED_ACTIVATE = ERROR_BASE + 12
 ERROR_POST_ACTIVATE_COMMAND = ERROR_BASE + 13
 ERROR_GET_LPAR_STATUS = ERROR_BASE + 14
 ERROR_UNEXP_LPAR_STATUS = ERROR_BASE + 15

 return  /* end function */

 /*******************************************************/
 /* Function:  JSON_getToolkitConstants                 */
 /*                                                     */
 /* Access constants used by the toolkit (for return    */
 /* codes, etc), via the HWTCONST toolkit api.          */
 /*                                                     */
 /* Returns: 0 if toolkit constants accessed, !0 if not */
 /*******************************************************/
JSON_getToolkitConstants:

 call TraceJSONVerbose 'Setting hwtcalls on'

 /***********************************************/
 /* Ensure that the toolkit host command is     */
 /* available in your REXX environment (no harm */
 /* done if already present).  Do this before   */
 /* your first toolkit api invocation.          */
 /***********************************************/
 call hwtcalls "on"

 call TraceJSONVerbose 'Including HWT Constants...'

 /************************************************/
 /* Call the HWTCONST toolkit api.  This should  */
 /* make all toolkit-related constants available */
 /* to procedures via (expose of) HWT_CONSTANTS  */
 /************************************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtconst ",
                 "ReturnCode ",
                 "DiagArea."
 RexxRC = RC
 If JSON_isError( RexxRC, ReturnCode ) Then
     Do
     call JSON_surfaceDiag 'hwtconst', RexxRC, ReturnCode, DiagArea.
     return fatalError( ERROR_TOOLKIT_CONSTANTS,,
                        '** hwtconst (json) failure **' )
     End /* endif hwtconst error */

 return NO_ERROR  /* end subroutine */


 /*********************************************************************/
 /* Function: JSON_initParser                                         */
 /*                                                                   */
 /* Creates a Json parser instance via the HWTJINIT toolkit api.      */
 /* Initializes the global variable parserHandle with the handle      */
 /* returned by the api.  This handle is required by other toolkit    */
 /* api's (and so this HWTJINIT api must be invoked before invoking   */
 /* any other parse-related api).                                     */
 /*                                                                   */
 /* Returns: 0 if successful, !0 if not.                              */
 /*********************************************************************/
JSON_initParser:

 call TraceJSONVerbose 'Initializing Json Parser'

 /***********************************/
 /* Call the HWTJINIT toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjinit ",
                 "ReturnCode ",
                 "handleOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjinit', RexxRC, ReturnCode, DiagArea.
    return fatalError( ERROR_PARSER,'** hwtjinit failure **' )
    end  /* endif hwtjinit failure */

 /********************************/
 /* Set the all-important global */
 /********************************/
 ParserHandle = handleOut
 isParserInit = '1'

 call TraceJSONVerbose 'Json Parser init (hwtjinit) succeeded'

 return NO_ERROR  /* end function */


 /*******************************************************************/
 /* Function:  GetCpcUri                                            */
 /*                                                                 */
 /* Make an HWIREST Get request for information about the named CPC */
 /* and extract its target name and object uri from the Json        */
 /* Response body for use with subsequent HWIREST requests.         */
 /*                                                                 */
 /* Returns: 0 if successful, !0 if not                             */
 /*                                                                 */
 /*******************************************************************/
GetCpcUri:

 call TraceMessage ' '
 call TraceMessage 'Obtaining CPC URI and TargetName'

 argName = UpperCase(STRIP(arg(1)))

 argUri = '/api/cpcs?name='||argName
 ExpectedHttpStatus = HTTP_STATUS_OK

 If DoGet( argUri ) <> NO_ERROR Then
    return fatalError( GetRc, '** DoGet( '||argUri||' ) failure **' )

 If HwirestRequestStatus <> ExpectedHttpStatus Then
    return fatalError( ERROR_GET_CPC_INFO,,
         '** Unexpected Http Status '||HwirestRequestStatus||' **' )

 /* Parse the response body */
 If JSON_parseJson( ResponseJson ) <> NO_ERROR Then
   return fatalError( ERROR_GET_LPAR_INFO,,
                             '** Parse Failure '||ParseRc||' **' )

 /* Search the Json response body for the Cpcs array */
 ArrayHandle = JSON_findValue( RootHandle,,
                                        JSON_ATTR_CPCS,,
                                        HWTJ_ARRAY_TYPE )
 If ArrayHandle = '' Then
   return fatalError( ERROR_GET_CPC_INFO,,
                                '** Array Handle not found **' )

 /*************************************************/
 /* Find the Cpc Target Name and Object Uri,      */
 /* needed to qualify subsequent requests.        */
 /* Note that the array indexing is 0-based.      */
 /* Because we request a specifc CPC by name,     */
 /* there should be only 1 entry                  */
 /*************************************************/
 numEntries = JSON_getArrayDim( ArrayHandle )
 If numEntries = '' Then
   return fatalError( ERROR_GET_CPC_INFO,,
                                '** Unexpected Array dim error  **' )
 If numEntries <= 0 Then
   return fatalError( ERROR_GET_CPC_INFO,,
                                '** CPC Not Found  **' )
 If numEntries > 1 Then
   return fatalError( ERROR_GET_CPC_INFO,,
                     '** Unexpected Array dim error  **' )

   entryHandle = JSON_getArrayEntry( ArrayHandle, 0 )
   If entryHandle = '' Then
     return fatalError( ERROR_GET_CPC_INFO,,
                              '** Unexpected Entry handle error  **' )
   CpcTargetName = JSON_findValue( entryHandle,,
                                  JSON_ATTR_TARGETNAME,,
                                  HWTJ_STRING_TYPE )
   If CpcTargetName = '' Then
    return fatalError( ERROR_GET_CPC_INFO,,
                              '** CPC Targetname not found  **' )


   CpcUri = JSON_findValue( entryHandle,,
                            JSON_ATTR_OBJECTURI,,
                            HWTJ_STRING_TYPE )
   If CpcUri = '' Then
     return fatalError( ERROR_GET_CPC_INFO,,
                       '** CPC URI Not Found  **' )

 call TraceMessage 'CPC TargetName: '||CpcTargetName
 call TraceMessage 'CPC Uri: '||CpcUri

 return NO_ERROR  /* end function */

 /*******************************************************************/
 /* Function:  GetLparUri                                           */
 /*                                                                 */
 /* Make an HWIREST Get request for information about the named     */
 /* LPAR (the CpcUri obtained earlier serves to scope the Lpar      */
 /* name).  Extract the target name and object uri from the Json    */
 /* response body for use with subsequent HWIREST requests.         */
 /*                                                                 */
 /* Returns: 0 if successful, !0 if not                             */
 /*                                                                 */
 /*******************************************************************/
GetLparUri:

 call TraceMessage ' '
 call TraceMessage 'Obtaining LPAR URI, TargetName and Status'

 argLPARName = UpperCase(STRIP(arg(1)))

 argUri = CpcUri||'/logical-partitions?name='||argLPARName
 ExpectedHttpStatus = HTTP_STATUS_OK

 If DoGet( argUri, CpcTargetName ) <> NO_ERROR Then
    return fatalError( GetRc, '** DoGet( '||argUri||' ) failure **' )

 If HwirestRequestStatus <> ExpectedHttpStatus Then
   return fatalError( ERROR_GET_LPAR_INFO,,
         '** Unexpected Http Status '||HwirestRequestStatus||' **' )

 /* Parse the response body */
 If JSON_parseJson( ResponseJson ) <> NO_ERROR Then
   return fatalError( ERROR_GET_LPAR_INFO,,
                             '** Parse Failure '||ParseRc||' **' )

 /* Search the Json response body for the Lpars array */
 ArrayHandle = JSON_findValue( RootHandle,,
                               JSON_ATTR_LOGICAL_PARTITIONS,,
                               HWTJ_ARRAY_TYPE )

 If ArrayHandle = '' Then
             return fatalError( ERROR_GET_LPAR_INFO,,
                                '** Array Handle not found **' )
 numEntries = JSON_getArrayDim( ArrayHandle )
 If numEntries = '' Then
      return fatalError( ERROR_GET_LPAR_INFO,,
                                '** Unexpected Array dim error **' )
 If numEntries <= 0 Then
      return fatalError( ERROR_GET_LPAR_INFO,,
                                '** LPAR Not Found **' )
 If numEntries > 1 Then
   return fatalError( ERROR_GET_LPAR_INFO,,
                           '** Unexpected Array dim error  **' )

  entryHandle = JSON_getArrayEntry( ArrayHandle, 0 )
    If entryHandle = '' Then
    return fatalError( ERROR_GET_LPAR_INFO,,
                           '** Unexpected Entry handle error  **' )
  LparTargetName = JSON_findValue( entryHandle,,
                                   JSON_ATTR_TARGETNAME,,
                                   HWTJ_STRING_TYPE )
   If LparTargetName = '' Then
     return fatalError( ERROR_GET_LPAR_INFO,,
                        '** LPAR TargetName Not Found  **' )

   LparUri = JSON_findValue( entryHandle,,
                             JSON_ATTR_OBJECTURI,,
                             HWTJ_STRING_TYPE )
   If LparUri = '' Then
     return fatalError( ERROR_GET_LPAR_INFO,,
                        '** LPAR URI Not Found  **' )

   LparStatus = JSON_findValue( entryHandle,,
                                JSON_ATTR_STATUS,,
                                HWTJ_STRING_TYPE )

   If LparStatus = '' Then
     return fatalError( ERROR_GET_LPAR_INFO,,
                        '** LPAR STATUS Not Found  **' )

 call TraceMessage 'LPAR TargetName: '||LparTargetName
 call TraceMessage 'LPAR Uri: '||LparUri
 call TraceMessage 'LPAR Status: '||LparStatus
 call TraceMessage ' '

 /************************************************************/
 /* Here we check LparStatus, as we do not wish to invoke    */
 /* load against an operating Lpar (or an LPAR with a status */
 /* of exceptions or acceptable).                            */
 /* If an activate is needed we indicate that needs to be    */
 /* done first. You may wish to alter this section to suit   */
 /* your own purposes.                                       */
 /************************************************************/
 If LparStatus = LPAR_STATUS_NOT_ACTIVATED Then
   return ERROR_NEED_ACTIVATE
  Else If (LparStatus <> LPAR_STATUS_NOT_OPERATING) Then
    return fatalError( ERROR_UNEXP_LPAR_STATUS,,
           '** Unexpected Lpar Status: '||LparStatus||' **' )

return NO_ERROR  /* end function */

 /*******************************************************/
 /* Function:  IssueLparActivateCommand                 */
 /*                                                     */
 /* Make an HWIREST Post request to invoke the ACTIVATE */
 /* operation for the LPAR designated by the input uri  */
 /* and extract the resulting job uri from the Json     */
 /* response body.                                      */
 /*                                                     */
 /* Returns: 0 if successful, !0 if not                 */
 /*******************************************************/
IssueLparActivateCommand:

 argUri = arg(1)
 activateUri = argUri||'/operations/activate'

 /* use the next-activation-profile-name value for the activate */
 activateRequestBody = '{}'

 call TraceMessage ' '
 call TraceMessage 'Invoke activate with uri: '||activateUri
 call TraceMessage 'Request Body: '||activateRequestBody

 ExpectedHttpStatus = HTTP_STATUS_ACCEPTED

 If DoPost( activateUri, activateRequestBody, LparTargetName ) <> NO_ERROR Then
   return fatalError( PostRc,,
                       '** DoPost( '||activateUri||' ) failure **'  )

 If HwirestRequestStatus <> ExpectedHttpStatus Then
   return fatalError( ERROR_POST_ACTIVATE_COMMAND,,
         '** Unexpected Http Status '||HwirestRequestStatus||' **' )

 /* Parse the response body */
 If JSON_parseJson( ResponseJson ) <>  NO_ERROR Then
   return fatalError( ERROR_POST_ACTIVATE_COMMAND,,
                             '** Parse Failure '||ParseRc||' **' )

  /* Search for the job uri associated with command */
 CommandJobUri = JSON_findValue( RootHandle,,
                                 JSON_ATTR_JOBURI,,
                                 HWTJ_STRING_TYPE )
 If CommandJobUri = '' Then
   return fatalError( ERROR_POST_ACTIVATE_COMMAND,,
                                '** JobUri not available **' )
 call TraceMessage 'JobUri: '||CommandJobUri

 return NO_ERROR  /* end function */

 /*******************************************************/
 /* Function:  IssueLparLoadCommand                     */
 /*                                                     */
 /* Make an HWIREST Post request to invoke the LOAD     */
 /* operation for the LPAR designated by the input uri  */
 /* and extract the resulting job uri from the Json     */
 /* response body.                                      */
 /*                                                     */
 /* Returns: 0 if successful, !0 if not                 */
 /*******************************************************/
IssueLparLoadCommand:

 argUri = arg(1)
 loadUri = argUri||'/operations/load'

 body1 = '{"clear-indicator":false, '
 body2 = '"store-status-indicator":true, '
 body3 = '"load-address":"'||ARG_LOAD_ADDR||'", '
 body4 = '"load-parameter":"'||ARG_LOAD_PARM||'" }'
 loadRequestBody = body1||body2||body3||body4

 call TraceMessage ' '
 call TraceMessage 'Invoke load with uri: '||loadUri
 call TraceMessage 'Request Body: '||loadRequestBody

 ExpectedHttpStatus = HTTP_STATUS_ACCEPTED

 If DoPost( loadUri, loadRequestBody, LparTargetName ) <> NO_ERROR Then
   return fatalError( PostRc,,
                       '** DoPost( '||loadUri||' ) failure **'  )

 If HwirestRequestStatus <> ExpectedHttpStatus Then
   return fatalError( ERROR_POST_LOAD_COMMAND,,
         '** Unexpected Http Status '||HwirestRequestStatus||' **' )

 /* Parse the response body */
 If JSON_parseJson( ResponseJson ) <>  NO_ERROR Then
   return fatalError( ERROR_POST_LOAD_COMMAND,,
                             '** Parse Failure '||ParseRc||' **' )

  /* Search for the job uri associated with command */
 CommandJobUri = JSON_findValue( RootHandle,,
                                 JSON_ATTR_JOBURI,,
                                 HWTJ_STRING_TYPE )
 If CommandJobUri = '' Then
   return fatalError( ERROR_POST_LOAD_COMMAND,,
                                '** JobUri not available **' )
 call TraceMessage 'JobUri: '||CommandJobUri

 return NO_ERROR  /* end function */

 /*******************************************************/
 /* Function:  PollJobStatus                            */
 /*                                                     */
 /* Poll for change in status of the designated job,    */
 /* or for excessive elapsed time.  Use the system rexx */
 /* AXRWAIT primitive to wait for a regular interval    */
 /* between successive polls.  If no job status change  */
 /* is sensed within the allotted time, then consider   */
 /* the outcome to be a fatal error, otherwise consider */
 /* the act of polling, at least, to be successful      */
 /* (the caller needs to decide if the resulting job    */
 /* status is acceptable).                              */
 /*                                                     */
 /* Returns: 0 if successful, !0 if not                 */
 /*******************************************************/
PollJobStatus:

 argJobUri = arg(1)
 argSecondsToWait = arg(2)
 argTimeLimit = arg(3)

 StopPolling = False
 AccumulatedWaitTime = 0
 CommandStatus = JOB_STATUS_RUNNING
 PollRc = NO_ERROR
 WaitRc = NO_ERROR

 Do While StopPolling = False

 call TraceMessage '  '
 call TraceMessage 'Polling Job Status'

    GetRc = GetJobStatus( argJobUri )

    If GetRc = NO_ERROR Then
      Do
        /* check if job is done or canceled        */
        If (CommandStatus = JOB_STATUS_COMPLETE) |,
           (CommandStatus = JOB_STATUS_CANCELED) Then
         StopPolling = True
        /* job not done, check if time limit exceeded */
        Else If  (AccumulatedWaitTime >= ArgTimeLimit) Then
          Do
            StopPolling = True
            PollRc = fatalError( ERROR_POLL,,
                       '** Time Limit Exceeded **' )
          End /* time exceeded */
        Else
          Do
            /* wait for specified interval */
            call TraceMessage 'Wait '||argSecondsToWait||' seconds...'
            AccumulatedWaitTime = AccumulatedWaitTime + argSecondsToWait

            If RUN_ENV = 'AXREXX' Then
              WaitRc = AXRWAIT( argSecondsToWait )
            Else
              WaitRc = NO_ERROR   /* dummy: address syscall sleep */

              If WaitRc <> NO_ERROR Then
                Do
                  StopPolling = True
                  PollRc = fatalError( ERROR_POLL,,
                             '** Wait failure '||WaitRc||' **' )
                End /* endif wait failed */
          End /* endif still polling */
      End /* endif getjobstatus ok */
    Else
      Do
        StopPolling = True
        PollRc = fatalError( GetRc,,
                             '** GetJobStatus failure '||GetRc||' **' )
      End  /* endif get status failed */
 End  /* endloop */

 return PollRc  /* end function */

 /*********************************************************************/
 /* Function:  GetJobStatus                                           */
 /*                                                                   */
 /* The async portion of a previously invoked command returned a job  */
 /* uri of the form:  /api/jobs/{job-id} and invoking an HWIREST GET  */
 /* request for that uri should return a response body containing     */
 /* attributes:                                                       */
 /*                                                                   */
 /*   "status": "running" or                                          */
 /*             "cancel-pending" or                                   */
 /*             "canceled" or                                         */
 /*             "complete"                                            */
 /*                                                                   */
 /*  and (only) if "complete" or "canceled"                           */
 /*      "job-status-code":<integer>                                  */
 /*      "job-results":<OBJECT> whose content varies with the command */
 /*  and (only) if job-status-code <> 2xx                             */
 /*       "job-reason-code":<integer>                                 */
 /*                                                                   */
 /* We care primarily about <status>, secondarily about               */
 /*  <job-status-code>, and potentially about <job-reason-code>.      */
 /*                                                                   */
 /* Returns: 0 if the value of <status> is obtained, !0 if not (the   */
 /*          actual success or failure of the job is purely the       */
 /*          caller's concern)                                        */
 /*                                                                   */
 /* NOTE: We should not rely solely on the presence of a status       */
 /* "complete" attribute. The presence of a "job-status-code"         */
 /* is a more reliable indication of success.  This status code is    */
 /* an http style code, anything in { 2xx } is desirable,             */
 /* any other status code indicates failure and will be accompanied   */
 /* by a "job-reason-code".                                           */
 /*                                                                   */
 /*********************************************************************/
GetJobStatus:

 argUri = arg(1)
 ExpectedHttpStatus = HTTP_STATUS_OK

 GetRc = DoGet( argUri, LparTargetName )

 If GetRc = NO_ERROR Then
   Do
   If HwirestRequestStatus = ExpectedHttpStatus Then
     Do
     /* Parse the response body */
     ParseRc = JSON_parseJson( ResponseJson )

     If ParseRc = NO_ERROR Then
       Do
       JobStatus = JSON_findValue( RootHandle,,
                                   JSON_ATTR_STATUS,,
                                   HWTJ_STRING_TYPE )
       Select
         When JobStatus = JOB_STATUS_RUNNING Then
           Do
            CommandStatus = JOB_STATUS_RUNNING
            ExecStatus = NO_ERROR
            call TraceMessage 'JobStatus: running'
           End
         When JobStatus = JOB_STATUS_CANCEL_PENDING Then
           Do
            CommandStatus = JOB_STATUS_CANCEL_PENDING
            ExecStatus = NO_ERROR
            call TraceMessage 'JobStatus: cancel pending'
           End
         When JobStatus = JOB_STATUS_CANCELED Then
           Do
            CommandStatus = JOB_STATUS_CANCELED
            JobStatusCode = JSON_findValue( RootHandle,,
                JSON_ATTR_JOBSTATUSCODE,,
                HWTJ_NUMBER_TYPE )
            call TraceMessasge 'JobStatus: canceled'
            call TraceMessage 'JobStatusCode: '||JobStatusCode
            If Substr( JobStatusCode, 1, 1 ) = '2' Then
              Do
                ExecStatus = NO_ERROR
                call TraceMessage 'Job completed successfully'
              End /* endif job successful */
            Else
              Do
                ExecStatus = ERROR_GET_JOB_RESULT
                call TraceMessage '*ERROR* Job unsuccessful'
                JobReasonCode = JSON_findValue( RootHandle,,
                                JSON_ATTR_JOBREASONCODE,,
                                HWTJ_NUMBER_TYPE )
                call TraceMessage 'JobReasonCode: '||JobReasonCode
                JobResults = JSON_findValue( RootHandle,,
                                JSON_ATTR_JOBMESSAGE,,
                                HWTJ_STRING_TYPE )
                call TraceMessage 'JobResults: '||JobResults
              End  /* endif job failure indicated */
           End /* job canceled */
         When JobStatus = JOB_STATUS_COMPLETE Then
           Do
            CommandStatus = JOB_STATUS_COMPLETE
            JobStatusCode = JSON_findValue( RootHandle,,
                JSON_ATTR_JOBSTATUSCODE,,
                HWTJ_NUMBER_TYPE )
            call TraceMessage 'JobStatus: complete'
            call TraceMessage 'JobStatusCode: '||JobStatusCode
            If Substr( JobStatusCode, 1, 1 ) = '2' Then
              Do
                ExecStatus = NO_ERROR
                call TraceMessage 'Job completed successfully'
              End /* endif job successful */
            Else
              Do
                ExecStatus = ERROR_GET_JOB_RESULT
                call TraceMessage '*ERROR* Job unsuccessful'
                JobReasonCode = JSON_findValue( RootHandle,,
                                JSON_ATTR_JOBREASONCODE,,
                                HWTJ_NUMBER_TYPE )
                call TraceMessage 'JobReasonCode: '||JobReasonCode
                JobResults = JSON_findValue( RootHandle,,
                                JSON_ATTR_JOBMESSAGE,,
                                HWTJ_STRING_TYPE )
                call TraceMessage 'JobResults: '||JobResults
              End  /* endif job failure indicated */
           End /* jobstatus complete */
         Otherwise
           Do
            /********************************************************/
            /* Job status does not match any expected value         */
            /********************************************************/
              return fatalError( ERROR_GET_JOB_STATUS,,
                               '** unexpected job status  **'||JobStatus )
         End /* end otherwise */
       End  /* end select */

     End /* endif parserc ok */
     Else
       return fatalError( ERROR_GET_JOB_STATUS,,
                          '** parse failure **' )
   End /* endif http status ok */
   Else
     return fatalError( ERROR_GET_JOB_STATUS,,
                 '** Unexpected HTTP status '||HwirestRequestStatus )
 End  /* endif doget ok */
 Else
    return fatalError( ERROR_GET_JOB_STATUS,,
                       '** DoGet '||argUri||' failure **' )

 return ExecStatus  /* end function */


 /*****************************************************************/
 /* Function:  DoGet                                              */
 /*                                                               */
 /* Invoke HWIREST, http method == GET, for the input uri and     */
 /* related args.                                                 */
 /*                                                               */
 /* Returns: 0 if no REXX error, !0 if REXX error (the success    */
 /*          or failure of the actual http request itself is      */
 /*          purely the concern of the caller).                   */
 /*****************************************************************/
DoGet:

 argUri = arg(1)
 argTarget = arg(2)

 drop Request.
 drop Response.
 drop ResponseJson

 Request.HTTPMETHOD = HWI_REST_GET
 Request.URI = argUri
 Request.TARGETNAME = argTarget
 Request.REQUESTTIMEOUT = HWIREST_MAXIMAL_TIMEOUT
 Request.REQUESTBODY = ''
 Request.CLIENTCORRELATOR = ''
 Request.ENCODING = 0
 HwirestRequestStatus = ''
 ResponseJson = ''

 call TraceMessage 'REQUEST ----->'
 call TraceMessage '>GET '|| Request.URI

 if Request.TARGETNAME <> '' then
   call TraceMessage '  >target name:'|| Request.TARGETNAME

 if Request.REQUESTBODY <> '' then
   call TraceMessage '  >request body:'|| Request.REQUESTBODY

 if VERBOSE then
   do
     call TraceMessage '  >timeout:'|| Request.REQUESTTIMEOUT
     if Request.CLIENTCORRELATOR <> '' then
       call TraceMessage '  >client correlator:'|| Request.CLIENTCORRELATOR
     call TraceMessage '  >encoding:'|| Request.ENCODING
   end

 address bcpii "hwirest ",
               "Request. ",
               "Response."
 RexxRC = RC

 If RexxRC <> NO_ERROR Then
   Do
     call surfaceResponse RexxRC, Response.
     return fatalError( ERROR_REXXENV,,
                       '** DoGet Rexx RC '||RexxRC||' **' )
   End

 If Response.httpStatus < 200 | Response.httpStatus > 299 Then
   call surfaceResponse RexxRC, Response.
 Else If VERBOSE Then
   call surfaceResponse RexxRC, Response.

 /* Set Globals */
 HwirestRequestStatus = Response.httpStatus
 ResponseJson = Response.responseBody

 return NO_ERROR

 /*****************************************************************/
 /* Function:  DoPost                                             */
 /*                                                               */
 /* Invoke HWIREST, http method == POST, for the input uri and    */
 /* related args.                                                 */
 /*                                                               */
 /* Returns: 0 if no REXX error, !0 if REXX error  (the success   */
 /*          or failure of the actual http request itself is      */
 /*          purely the concern of the caller).                   */
 /*****************************************************************/
DoPost:

 argUri = arg(1)
 argRequestBody = arg(2)
 argTarget = arg(3)

 drop Request.
 drop Response.
 drop ResponseJson

 Request.HTTPMETHOD = HWI_REST_POST
 Request.URI = argUri
 Request.TARGETNAME = argTarget
 Request.REQUESTTIMEOUT = HWIREST_MAXIMAL_TIMEOUT
 Request.REQUESTBODY = argRequestBody
 Request.CLIENTCORRELATOR = ''
 Request.ENCODING = 0
 HwirestRequestStatus = ''
 ResponseJson = ''

 call TraceMessage 'REQUEST ----->'
 call TraceMessage '>POST '|| Request.URI

 if Request.TARGETNAME <> '' then
   call TraceMessage '  >target name:'|| Request.TARGETNAME

 if Request.REQUESTBODY <> '' then
   call TraceMessage '  >request body:'|| Request.REQUESTBODY

 if VERBOSE then
   do
     call TraceMessage '  >timeout:'|| Request.REQUESTTIMEOUT
     if Request.CLIENTCORRELATOR <> '' then
       call TraceMessage '  >client correlator:'|| Request.CLIENTCORRELATOR
     call TraceMessage '  >encoding:'|| Request.ENCODING
   end

 address bcpii "hwirest ",
               "Request. ",
               "Response."
 RexxRC = RC

 If RexxRC <> NO_ERROR Then
   Do
     call surfaceResponse RexxRC, Response.
     return fatalError( ERROR_REXXENV,,
                       '** DoPost Rexx RC '||RexxRC||' **' )
   End

 If Response.httpStatus < 200 | Response.httpStatus > 299 Then
   call surfaceResponse RexxRC, Response.
 Else If VERBOSE Then
   call surfaceResponse RexxRC, Response.

 /* Set Globals */
 HwirestRequestStatus = Response.httpStatus
 ResponseJson = Response.responseBody

 return NO_ERROR

/********************************************************/
/* Procedure: surfaceResponse()                         */
/*            parse through the response parm and if    */
/*            the request failed showcase the issue     */
/*                                                      */
/********************************************************/
surfaceResponse:

  call TraceMessage 'RESPONSE ----->'
  call TraceMessage 'Rexx RC: ('||arg(1)||')'

  /* continue processing even if RC <> 0
     because additional information could
     have been returned in the response.
     to help understand the error
  */
  traceResponse = arg(2)

  call TraceMessage 'HTTP Status: ('||traceResponse.httpstatus||')'
  successIndex = INDEX(traceResponse.httpstatus, '2')

  if successIndex = 1 then
    do /* SE responded successfully */
     call TraceMessage 'SE DateTime: ('||traceResponse.responsedate||')'
     call TraceMessage 'SE requestId: (' || traceResponse.requestId || ')'

     if traceResponse.httpstatusNum = '201' Then
      call TraceMessage 'Location Response: (' || traceResponse.location || ')'

     if  traceResponse.responsebody <> '' Then
      do
       call TraceMessage 'Response Body: (' || traceResponse.responsebody || ')'
       return traceResponse.responsebody
      end
    end /* SE responded successfully */
  else
    do /* error path */
     call TraceMessage 'Reason Code: ('||traceResponse.reasoncode||')'

     if traceResponse.responsedate <> '' then
       call TraceMessage 'SE DateTime: ('||traceResponse.responsedate||')'

     if traceResponse.requestId <> '' Then
       call TraceMessage 'SE requestId: (' || traceResponse.requestId || ')'

     if traceResponse.responsebody <> '' Then
       do /* an error occurred */
         call JSON_parseJson traceResponse.responsebody

         if RESULT <> 0 then
          call TraceMessage 'failed to parse response'
         else
          do
            errmessage=JSON_findValue(0,JSON_ATTR_ERRMSG, HWTJ_STRING_TYPE)
            bcpiiErr=JSON_findValue(0, JSON_ATTR_BCPIIERR, HWTJ_BOOLEAN_TYPE)
            if bcpiiErr = 'true' then
              call TraceMessage '*** BCPii error message:('||errmessage||')'
            else
              call TraceMessage '*** SE error message:('||errmessage||')'
            end /* bcpii err */
        end /* response body */
    end /* error path */

 call TraceMessage '<---------'
 return '' /* end procedure */

 /*********************************************************************/
 /* Function:  JSON_parseJson                                         */
 /*                                                                   */
 /* Parse the input text body via call to the HWTJPARS toolkit api.   */
 /*                                                                   */
 /* HWTJPARS builds an internal representation of the input JSON text */
 /* which allows search, traversal, and modification operations       */
 /* against that representation.  Note that HWTJPARS does *not* make  */
 /* its own copy of the input source, and therefore the caller must   */
 /* ensure that the provided source string remains unmodified for the */
 /* duration of the associated parser instance (i.e., if the source   */
 /* string is modified, subsequent service call behavior and results  */
 /* from the parser are unpredictable).                               */
 /*                                                                   */
 /* Returns: 0 if successful, -1 if not.                              */
 /*********************************************************************/
JSON_parseJson:

 jsonTextBody = arg(1)

 call TraceJSONVerbose 'Invoke Json Parser'

 /***********************************/
 /* Call the HWTJPARS toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjpars ",
                 "ReturnCode ",
                 "parserHandle ",
                 "jsonTextBody ",
                 "DiagArea."
 RexxRC = RC

 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjpars', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjpars failure **' )
    end /* endif hwtjpars failure */

 call TraceJSONVerbose 'JSON parse successful'

 return NO_ERROR  /* end function */


 /**********************************************************/
 /* Function:  JSON_termParser                             */
 /*                                                        */
 /* Cleans up parser resources and invalidates the parser  */
 /* instance handle, via call to the HWTJTERM toolkit api. */
 /* Note that as the REXX environment is single-threaded,  */
 /* no consideration of any "busy" outcome from the api is */
 /* done (as it would be in other language environments).  */
 /*                                                        */
 /* Returns: 0 if successful, -1 if not.                   */
 /**********************************************************/
JSON_termParser:

 call TraceJSONVerbose 'Terminate Json Parser'

 /**********************************/
 /* Call the HWTJTERM toolkit api. */
 /**********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjterm ",
                 "ReturnCode ",
                 "parserHandle ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjterm', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjterm failure **' )
    end /* endif hwtjterm failure */

 call TraceJSONVerbose 'Json Parser terminated'
 return NO_ERROR  /* end function */


 /**********************************************************/
 /* Function:  JSON_findValue                              */
 /*                                                        */
 /* Return the value associated with the input name from   */
 /* the designated Json object, via the various toolkit    */
 /* api's { HWTJSRCH, HWTJGVAL, HWTJGBOV }, as appropriate.*/
 /*                                                        */
 /* Returns: The value of the designated entry in the      */
 /*          designated Json object, if found and of the   */
 /*          designated type, or empty string if not.      */
 /**********************************************************/
JSON_findValue:

 objectHandle = arg(1)
 searchName = arg(2)
 expectedType = arg(3)

 /********************************************************/
 /* Search the specified object for the specified name   */
 /********************************************************/
 call TraceJSONVerbose 'Invoke Json Search for '||searchName
 call TraceJSONVerbose 'ObjectHandle = '||objectHandle
 call TraceJSONVerbose 'ExpectedType = '||expectedType

 /********************************************************/
 /* Invoke the HWTJSRCH toolkit api.                     */
 /* The value 0 is specified (for the "startingHandle")  */
 /* to indicate that the search should start at the      */
 /* beginning of the designated object.                  */
 /********************************************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjsrch ",
                 "ReturnCode ",
                 "parserHandle ",
                 "HWTJ_SEARCHTYPE_GLOBAL",
                 "searchName ",
                 "0 ",
                 "objectHandle ",
                 "searchResult ",
                 "DiagArea."
 RexxRC = RC

 /********************************************/
 /* Return empty string if simply not found  */
 /********************************************/
 if JSON_isNotFound(RexxRC,ReturnCode) then
    return ''

 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjsrch', RexxRC, ReturnCode, DiagArea.
    call TraceMessage '** hwtjsrch failure **'
    return ''
    end /* endif hwtjsrch failed */

 /******************************************************/
 /* Process the search result, according to type.  We  */
 /* should first verify the type of the search result. */
 /******************************************************/
 resultType = JSON_getType( searchResult )
 if resultType <> expectedType then
    do
    call TraceJSONVerbose '** Type mismatch ( '||resultType,
                                     ||', '||expectedType||' ) **'
    return ''
    end /* endif unexpected type */

 /********************************************************/
 /* If the expected type is not a simple value, then the */
 /* search result is itself a handle to a nested object  */
 /* or array, and we simply return it as such.           */
 /********************************************************/
 if expectedType == HWTJ_OBJECT_TYPE,
            | expectedType == HWTJ_ARRAY_TYPE then
    do
    return searchResult
    end /* endif object or array type */

 /*******************************************************/
 /* Return the located string or number, as appropriate */
 /*******************************************************/
 if expectedType == HWTJ_STRING_TYPE,
            | expectedType == HWTJ_NUMBER_TYPE then
    do
    call TraceJSONVerbose 'Invoke Json Get Value'
    /***********************************/
    /* Call the HWTJGVAL toolkit api.  */
    /***********************************/
    ReturnCode = -1
    DiagArea. = ''
    address hwtjson "hwtjgval ",
                    "ReturnCode ",
                    "parserHandle ",
                    "searchResult ",
                    "result ",
                    "DiagArea."
    RexxRC = RC
    if JSON_isError(RexxRC,ReturnCode) then
       do
       call JSON_surfaceDiag 'hwtjgval', RexxRC, ReturnCode, DiagArea.
       call TraceMessage '** hwtjgval failure **'
       return ''
       end /* endif hwtjgval failed */

    return result
    end /* endif string or number type */

 /****************************************************/
 /* Return the located boolean value, as appropriate */
 /****************************************************/
  if expectedType == HWTJ_BOOLEAN_TYPE then
    do
    call TraceJSONVerbose 'Invoke Json Get Boolean Value'

    /***********************************/
    /* Call the HWTJGBOV toolkit api.  */
    /***********************************/
    ReturnCode = -1
    DiagArea. = ''
    address hwtjson "hwtjgbov ",
                    "ReturnCode ",
                    "parserHandle ",
                    "searchResult ",
                    "result ",
                    "DiagArea."
     RexxRC = RC
     if JSON_isError(RexxRC,ReturnCode) then
       do
       call JSON_surfaceDiag 'hwtjgbov', RexxRC, ReturnCode, DiagArea.
       call TraceMessage '** hwtjgbov failure **'
       return ''
       end /* endif hwtjgbov failed */

    return result
    end /* endif boolean type */

 /**********************************************/
 /* This return should not occur, in practice. */
 /* Note that we did not account for expected  */
 /* type == HWTJ_NULL_TYPE above, and could do */
 /* so here if that were meaningful (but more  */
 /* efficiently we might do that earlier in    */
 /* the routine to avoid wasteful processing). */
 /**********************************************/
 call TraceMessage '** No return value found **'
 return ''  /* end function */


 /***********************************************************/
 /* Function:  JSON_getType                                 */
 /*                                                         */
 /* Determine the Json type of the designated search result */
 /* via the HWTJGJST toolkit api.                           */
 /*                                                         */
 /* Returns: Non-negative integral number indicating type   */
 /*          if successful, -1 if not.                      */
 /***********************************************************/
JSON_getType:

 searchResult = arg(1)

 call TraceJSONVerbose 'Invoke Json Get Type'

 /***********************************/
 /* Call the HWTJGJST toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgjst ",
                 "ReturnCode ",
                 "parserHandle ",
                 "searchResult ",
                 "resultTypeName ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjgjst', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjgjst failure **' )
    end /* endif hwtjgjst failure */
 else
    do
    /*******************************************************/
    /* Convert the returned type name into its equivalent  */
    /* constant, and return that more convenient value.    */
    /* Note that the interpret instruction might more      */
    /* typically be used here, but the goal here is to     */
    /* familiarize the reader with these types.            */
    /*******************************************************/
    type = strip(resultTypeName)
    if type == 'HWTJ_STRING_TYPE' then
       return HWTJ_STRING_TYPE
    if type == 'HWTJ_NUMBER_TYPE' then
       return HWTJ_NUMBER_TYPE
    if type == 'HWTJ_BOOLEAN_TYPE' then
       return HWTJ_BOOLEAN_TYPE
    if type == 'HWTJ_ARRAY_TYPE' then
       return HWTJ_ARRAY_TYPE
    if type == 'HWTJ_OBJECT_TYPE' then
       return HWTJ_OBJECT_TYPE
    if type == 'HWTJ_NULL_TYPE' then
       return HWTJ_NULL_TYPE
    end /* endif hwtjgjst ok */

 /**********************************************/
 /* This return should not occur, in practice. */
 /**********************************************/
 return fatalError( 'Unsupported Type ('||type||') from hwtjgjst' )


 /*************************************************************/
 /* Function:  JSON_isNotFound                                */
 /*                                                           */
 /* Check the input processing codes. Note that if the input  */
 /* RexxRC is nonzero, then the toolkit return code is moot   */
 /* (the toolkit function was likely not even invoked). If    */
 /* the toolkit return code is relevant, check it against the */
 /* specific return code for a "not found" condition.         */
 /*                                                           */
 /* Returns:  1 if HWTJ_JSRCH_SRCHSTR_NOT_FOUND condition, 0  */
 /*           otherwise.                                      */
 /*************************************************************/
JSON_isNotFound:

 RexxRC = arg(1)

 if RexxRC <> 0 then
    return 0

 ToolkitRC = strip(arg(2),'L',0)
 if ToolkitRC == HWTJ_JSRCH_SRCHSTR_NOT_FOUND then
    return 1

 return 0  /* end function */


 /*************************************************************/
 /* Function:  JSON_isError                                   */
 /*                                                           */
 /* Check the input processing codes. Note that if the input  */
 /* RexxRC is nonzero, then the toolkit return code is moot   */
 /* (the toolkit function was likely not even invoked). If    */
 /* the toolkit return code is relevant, check it against the */
 /* set of { HWTJ_xx } return codes for evidence of error.    */
 /* This set is ordered: HWTJ_OK < HWTJ_WARNING < ...         */
 /* with remaining codes indicating error, so we may check    */
 /* via single inequality.                                    */
 /*                                                           */
 /* Returns:  1 if any toolkit error is indicated, 0          */
 /*           otherwise.                                      */
 /*************************************************************/
JSON_isError:

 RexxRC = arg(1)

 if RexxRC <> 0 then
    return 1

 ToolkitRC = strip(arg(2),'L',0)
 if ToolkitRC == '' then
       return 0

 if ToolkitRC <= HWTJ_WARNING then
       return 0

 return 1  /* end function */


 /***********************************************/
 /* Procedure: JSON_surfaceDiag                 */
 /*                                             */
 /* Surface input error information.  Note that */
 /* when the RexxRC is nonzero, the ToolkitRC   */
 /* and DiagArea content are moot and are       */
 /* suppressed (so as to not mislead).          */
 /*                                             */
 /***********************************************/
JSON_surfaceDiag: procedure expose DiagArea.

  who = arg(1)
  RexxRC = arg(2)
  ToolkitRC = arg(3)

  call TraceMessage '*ERROR* ('||who||') at time: '||Time()
  call TraceMessage 'Rexx RC: '||RexxRC,
                         ||', Toolkit ReturnCode: '||ToolkitRC

  if RexxRC == 0 then
     do
     call TraceMessage 'DiagArea.ReasonCode: '||DiagArea.HWTJ_ReasonCode
     call TraceMessage 'DiagArea.ReasonDesc: '||DiagArea.HWTJ_ReasonDesc
     end

 return  /* end procedure */


 /**********************************************/
 /* Function:  fatalError                       */
 /*                                             */
 /* Surfaces the input message, and echoes      */
 /* (returns) the input failure code.           */
 /*                                             */
 /* Returns: as described above                 */
 /***********************************************/
fatalError:

 errorCode = arg(1)
 errorMsg = arg(2)

 call TraceMessage errorMsg

 return errorCode  /* end function */


 /********************************************************************/
 /* Procedure:  TraceMessage                                         */
 /********************************************************************/
TraceMessage:

 /*
 Uncomment if you'd like a prefix for the message:
 TraceMsg = THIS_EXEC||'>'||arg(1)
 */
 TraceMsg = arg(1)
 TraceRc = NO_ERROR

 /* Alternatively if you wanted to trace to the console log:
    WTO_MSGSIZE_LIMIT = 126   <--AXRWTOR limit
    If LENGTH(TraceMsg) > WTO_MSGSIZE_LIMIT Then
       TraceMsg = LEFT(TraceMsg,WTO_MSGSIZE_LIMIT)
    TraceRc = AXRWTO( TraceMsg )
 */
 say TraceMsg

 return /* end procedure */


 /*******************************************************************/
 /* Procedure:  TraceJSONVerbose                                        */
 /*                                                                 */
 /* Invoke TraceMessage if and only if VERBOSE is desired           */
 /*******************************************************************/
TraceJSONVerbose:

 If VERBOSE Then
    call TraceMessage arg(1)

 return /* end procedure */


/*******************************************************************/
/* Function:  UpperCase                                            */
/*                                                                 */
/* Return a version of the input string folded to upper case       */
/*******************************************************************/
UpperCase:

 argString = arg(1)
 alphaTo = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
 alphaFrom = 'abcdefghijklmnopqrstuvwxyz'
 upString = TRANSLATE(argString,alphaTo,alphaFrom)

 return upString /* end function */


/**************************************************/
/* Function:  JSON_getArrayDim                    */
/*                                                */
/* Return the number of entries in the array      */
/* designated by the input handle, obtained       */
/* via the HWTJGNUE toolkit api.                  */
/*                                                */
/* Returns: Non-negative integral number of array */
/* entries if successful, -1 if not.              */
/**************************************************/
JSON_getArrayDim:

 arrayHandle = arg(1)
 arrayDim = 0
 call TraceJSONVerbose 'Getting array dimension'

 /***********************************/
 /* Call the toolkit HWTJGNUE api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgnue ",
                 "ReturnCode ",
                 "parserHandle ",
                 "arrayHandle ",
                 "dimOut ",
                 "DiagArea."
 RexxRC = RC
 If JSON_isError(RexxRC,ReturnCode) Then
    call JSON_surfaceDiag 'hwtjgnue', RexxRC, ReturnCode, DiagArea.
 Else
    Do
    arrayDim = strip(dimOut,'L',0)
    If arrayDim == '' Then
       arrayDim = 0
    End

 return arrayDim  /* end function */


/*************************************************/
/* Function:  JSON_getArrayEntry                */
/*                                              */
/* Return a handle to the designated entry of   */
/* the array designated by the input handle,    */
/* obtained via the HWTJGAEN toolkit api.       */
/*                                              */
/* Returns: Output handle from toolkit api if   */
/* successful, empty result if not.             */
/************************************************/
JSON_getArrayEntry:

 arrayHandle = arg(1)
 whichEntry = arg(2)

 result = ''
 call TraceJSONVerbose 'Getting array entry'

 /***********************************/
 /* Call the toolkit HWTJGAEN api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgaen ",
                 "ReturnCode ",
                 "parserHandle ",
                 "arrayHandle ",
                 "whichEntry ",
                 "handleOut ",
                 "DiagArea."
 RexxRC = RC
 If JSON_isError(RexxRC,ReturnCode) Then
    call JSON_surfaceDiag 'hwtjgaen', RexxRC, ReturnCode, DiagArea.
 Else
    result = handleOut

 return result  /* end function */

 /*******************************************************/
 /* Function:  VerifyRequiredArgs                       */
 /*                                                     */
 /* Returns:  0 to indicate that all args were properly */
 /*           supplied, !0 to indicate otherwise.       */
 /*******************************************************/
VerifyRequiredArgs:

  parmsRC = NO_ERROR

  If LENGTH(ARG_CPC_NAME) > 0 Then
   call TraceMessage 'CPC NAME = '||ARG_CPC_NAME
  Else
   Do
     parmsRC = ERROR_ARGS
     call TraceMessage '*ERROR* ARG_CPC_NAME value missing or invalid'
   End

  If LENGTH(ARG_LPAR_NAME) > 0 Then
   call TraceMessage 'LPAR NAME = '||ARG_LPAR_NAME
  Else
   Do
     parmsRC = ERROR_ARGS
     call TraceMessage '*ERROR* ARG_LPAR_NAME value missing or invalid'
   End

  If LENGTH(ARG_LOAD_ADDR) > 0 Then
   call TraceMessage 'LOAD Address = '||ARG_LOAD_ADDR
  Else
   Do
     parmsRC = ERROR_ARGS
     call TraceMessage '*ERROR* ARG_LOAD_ADDR value missing or invalid'
   End

  If LENGTH(ARG_LOAD_PARM) > 0 Then
   call TraceMessage 'LOAD Parm = '||ARG_LOAD_PARM
  Else
   Do
     parmsRC = ERROR_ARGS
     call TraceMessage '*ERROR* ARG_LOAD_PARM value missing or invalid'
   End

  return parmsRC  /* end function */