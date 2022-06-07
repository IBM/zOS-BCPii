/* REXX */
/* START OF SPECIFICATIONS *********************************************/
/* Beginning of Copyright and License                                  */
/*                                                                     */
/* Copyright 2022 IBM Corp.                                            */
/*                                                                     */
/* Licensed under the Apache License, Version 2.0 (the "License");     */
/* you may not use this file except in compliance with the License.    */
/* You may obtain a copy of the License at                             */
/*                                                                     */
/* http://www.apache.org/licenses/LICENSE-2.0                          */
/*                                                                     */
/* Unless required by applicable law or agreed to in writing,          */
/* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,        */
/* either express or implied.  See the License for the specific        */
/* language governing permissions and limitations under the License.   */
/*                                                                     */
/* End of Copyright and License                                        */
/***********************************************************************/
/*                                                                     */
/*  SCRIPT NAME=RXENRGY1                                               */
/*                                                                     */
/*  DESCRIPTIVE NAME:                                                  */
/*    Sample REXX code which uses HWIREST API to query CPC             */
/*    energy information. Takes advantage of the JSON Parser           */
/*    to retrieve various pieces of the information.                   */
/*                                                                     */
/* OPERATION:                                                          */
/*                                                                     */
/*  CODE FLOW in this sample:                                          */
/*    Call List CPCs to retrieve uri and target name for the CPC       */
/*    Call Query Energy to retrieve energy related attributes          */
/*    Write collected content out to the provided partitioned data set */
/*                                                                     */
/* INVOCATION:                                                         */
/*     RXENRGY1 -D outputDataSet [-C CPCname] [-I] [-V]                */
/*                                                                     */
/*     Required input parameters:                                      */
/*        -D <data set name> is the fully qualified name of a          */
/*           pre-existing partitioned data set.                        */
/*           If the query is successful, a member containing the       */
/*           energy properties in CSV format will be stored in the     */
/*           data set.  The member will either be named LOCAL or the   */
/*           CPC name provided via the -C option.                      */
/*     Optional input parameters:                                      */
/*        -C <CPCname> name of the CPC to query, default is LOCAL CPC  */
/*        -I indicate running in ISV REXX environment,                 */
/*           default is TSO/E                                          */
/*        -V turn on additional verbose JSON tracing                   */
/*                                                                     */
/*        EX 'HWI.HWIREST.REXX(RXENRGY1))'                             */
/*            '-D HWI.ENERGY -I'                                       */
/*            data set is HWI.ENERGY, run from ISV REXX                */
/*            if successful will create HWI.ENERGY(LOCAL)              */
/*                                                                     */
/* DEPENDENCIES:                                                       */
/*     NONE                                                            */
/*                                                                     */
/* NOTES:                                                              */
/*     No recovery logic has been supplied in this sample.             */
/*                                                                     */
/* REFERENCE:                                                          */
/*     See the z/OS MVS Programming: Callable Services for             */
/*     High-Level Languages publication for more information           */
/*     regarding the usage of HWIREST and JSON Parser APIs.            */
/*                                                                     */
/*     See the Hardware Management Console Web Services API            */
/*     publication for the description of the energy                   */
/*     mangement related properties in the CPC data model.             */
/*     The properties in the CSV output file are listed in the         */
/*     order shown in the data model.                                  */
/*                                                                     */
/* END OF SPECIFICATIONS  * * * * * * * * * * * * * * * * * * * * * * **/

MACLIB_DATASET = 'SYS1.MACLIB'

TEMP_DATASET = '' /* required input via -D */
MEMBER_NAME = 'LOCAL' /* default CPC */

TRUE = 1
FALSE = 0

hwiHostRC = 0     /* HWIHOST rc */
HWIHOST_ON = FALSE
PARSER_INIT = FALSE
ISVREXX = FALSE  /* default to TSO/E, enable via -I */
VERBOSE = FALSE  /* JSON parser specific, enabled via -V */
localCPC = TRUE  /* default to the LOCAL CPC, change via -C */

/*********************************/
/* Get program args              */
/*********************************/
parse arg argString
if GetArgs(argString) <> 0 then
  exit -1

/*********************************/
/* Ensure the output dataset     */
/* specified actually exists     */
/* before proceeding.            */
/*********************************/
if VerifyDataSet(TEMP_DATASET) <> 0 then
  exit fatalErrorAndCleanup('** specified data set does not exist **')

if localCPC then
  say 'Obtaining Energy Info on LOCAL CPC'
else
  say 'Obtaining Energy Info on CPC:'||CPCname

if ISVREXX then
  do
    say 'Running in an ISV REXX environment'
    hwiHostRC = hwihost("ON")
    say 'HWIHOST("ON") return code is :('||hwiHostRC||')'

    if hwiHostRC <> 0 then
      exit fatalErrorAndCleanup('** unable to turn on HWIHOST **')
    HWIHOST_ON = TRUE
  end

call IncludeConstants

call JSON_getToolkitConstants
if RESULT <> 0 then
  exit fatalErrorAndCleanup( '** Environment error **' )

PROC_GLOBALS = 'VERBOSE parserHandle '||HWT_CONSTANTS

/*********************************/
/* Create a new parser instance. */
/*********************************/
parserHandle = ''
call JSON_initParser
if RESULT <> 0 then
  exit fatalErrorAndCleanup( '** Parser init failure **' )

/*********************************/
/* Start of BCPii logic          */
/*********************************/
if localCPC then
  do
    if getLocalCPCInfo() <> 0 then
      exit fatalErrorAndCleanup( '** failed to get LOCAL CPC info **' )
  end
else
  do
    if getCPCInfo() <> 0 then
      do
        errMsg = '** failed to get CPC info for ('||CPCname||') **'
        exit fatalErrorAndCleanup(errMsg)
      end
    MEMBER_NAME = CPCname
  end

/**************************************************/
/*  prime the lisf of attributes to be retrieved  */
/**************************************************/
call PrepEnergyAttributes
call PrepHdrRow

/**************************************************/
/*  Query attributes                              */
/**************************************************/
if QueryEnergy() <> 0 then
  exit fatalErrorAndCleanup( '** failed to obtain energy info **' )

/**************************************************/
/*  Write Results                                 */
/**************************************************/
 tempFile ="'"||TEMP_DATASET||"("||MEMBER_NAME||")'"

 if WriteToFile(tempFile) <> 0 then
   do
     errMsg = '** failed to write out content to ('||tempFile||') **'
     exit fatalErrorAndCleanup(errMsg)
   end
 else
   do
     say 'Results successfully written to ('||tempFile||')'
   end

call Cleanup

return 0 /* end main */

/*******************************************************/
/* Function: Cleanup                                   */
/*                                                     */
/* Terminate the parser instance and, if running in an */
/* ISV REXX environment, turn off HWIHOST.             */
/*******************************************************/
Cleanup:

if PARSER_INIT then
  do
    /* set ahead of time because we want to avoid an endless error
       loop in the event JSON_termParser invokes fatalError and
       goes through this path again
    */
    PARSER_INIT = FALSE
    call JSON_termParser
  end

if HWIHOST_ON then
  do
    /* set ahead of time because we want to avoid an endless error
       loop in the event HWIHOST(OFF) fails and invokes fatalError,
       which will goes through this path again
    */
    HWIHOST_ON = FALSE
    hwiHostRC = hwihost("OFF")
    say 'HWIHOST("OFF") return code is: ('||hwiHostRC||')'

    if hwiHostRC <> 0 then
      exit fatalErrorAndCleanup('** unable to turn off HWIHOST **')
  end

return 0

/*******************************************************/
/* Function:  GetLocalCPCInfo                          */
/*                                                     */
/* Retrieve the uri and target name associated with    */
/* LOCAL CPC and prime CPCuri and CPCtargetName        */
/* variables with the info                             */
/*                                                     */
/* Return 0 on success, -1 on error                    */
/*******************************************************/
GetLocalCPCInfo:

emptyCPCResponse = '{"cpcs":[]}'
localCPCfound = FALSE

/* First list the cpcs, then retrieve LOCAL
   CPC which will have
           "location":"local"

   GET /api/cpcs
*/
reqUri = '/api/cpcs'
CPCInfoResponse = GetRequest(reqUri)

emptyCPCArray = INDEX(CPCInfoResponse, emptyCPCResponse)
if emptyCPCArray > 0 | CPCInfoResponse = '' Then
  do
    return fatalError('** failed to get CPC info **')
  end

/* Parse the response to obtain the uri
   and target name associated with CPC,
*/
call JSON_parseJson CPCInfoResponse
CPCArray = JSON_findValue(0, "cpcs", HWTJ_ARRAY_TYPE)
if foundJSONValue(CPCArray) = FALSE then
  do
    return fatalError('** failed to retrieve CPCs **')
  end

/**************************************************************/
 /* Determine the number of CPCs represented in the array     */
 /**************************************************************/
 CPCs = JSON_getArrayDim(CPCArray)
 if CPCs <= 0 then
    return fatalError( '** Unable to retrieve number of array entries **' )

 /********************************************************************/
 /* Traverse the CPCs array to populate CPCsList.                    */
 /* We use the REXX (1-based) idiom  but adjust for the differing    */
 /* (0-based) idiom of the toolkit.                                  */
 /********************************************************************/
 say 'Processing information for '||CPCs||' CPC(s)... searching for LOCAL'
 do i = 1 to CPCs
    nextEntryHandle = JSON_getArrayEntry(CPCArray,i-1)
    CPClocation = JSON_findValue(nextEntryHandle,"location",HWTJ_STRING_TYPE)

    if CPClocation = 'local' then
      do
        say 'found LOCAL CPC'
        if localCPCfound = TRUE then
          do
            return fatalError('** found two LOCAL CPCs **')
          end
        localCPCfound = TRUE

        CPCuri=JSON_findValue(nextEntryHandle,"object-uri",HWTJ_STRING_TYPE)
        if foundJSONValue(CPCuri) = FALSE then
          do
            return fatalError,
            ('ERROR: found LOCAL CPC but it did not contain an object-uri')
          end

        CPCtargetName=JSON_findValue(nextEntryHandle,"target-name",,
                                    HWTJ_STRING_TYPE)
        if foundJSONValue(CPCtargetName) = FALSE then
          do
            return fatalError,
            ('ERROR: found LOCAL CPC but it did not contain target-name')
          end

        CPCname=JSON_findValue(nextEntryHandle,"name",HWTJ_STRING_TYPE)
        if foundJSONValue(CPCname) = FALSE then
          do
            return fatalError,
            ('ERROR: found LOCAL CPC but it did not contain a name property')
          end
      end
 end /* endloop CPCs */

if localCPCfound then
  do
    Say
    Say 'Successfully obtained LOCAL CPC Info:'
    Say '  name:'||CPCname
    Say '  uri:'||CPCuri
    Say '  target-name:'||CPCtargetName
    Say
    return 0
  end


/* if we're still here than something went wrong */
return fatalError('ERROR - ** failed to obtain LOCAL CPC info **')

/*******************************************************/
/* Function:  GetCPCInfo                               */
/*                                                     */
/* Retrieve the uri and target name associated with    */
/* CPCname and prime CPCuri and CPCtargetName          */
/* variables with the info                             */
/*                                                     */
/* Return 0 if successful, otherwise return -1         */
/*******************************************************/
GetCPCInfo:

methodSuccess = TRUE /* assume success */
emptyCPCResponse = '{"cpcs":[]}'

/* List information for specific CPC

   GET /api/cpcs?name=CPCname

   v1: HWICONN(HWI_CPC,IBM390PS.CPC)

*/
reqUri = '/api/cpcs?name='||CPCname
CPCInfoResponse = GetRequest(reqUri)

emptyCPCArray = INDEX(CPCInfoResponse, emptyCPCResponse)
if emptyCPCArray > 0 | CPCInfoResponse = '' Then
  do
    return fatalError('** failed to retrieve CPC **')
  end

/* Parse the response to obtain the uri
   and target name associated with CPC
*/
call JSON_parseJson CPCInfoResponse

CPCuri = JSON_findValue(0,"object-uri", HWTJ_STRING_TYPE)
if foundJSONValue(CPCuri) = FALSE then
  methodSuccess = FALSE

CPCtargetName = JSON_findValue(0,"target-name", HWTJ_STRING_TYPE)
if foundJSONValue(CPCtargetName) = FALSE then
  methodSuccess = FALSE

if methodSuccess then
  do
    Say
    Say 'Successfully obtained CPC Info:'
    Say '  uri:'||CPCuri
    Say '  target-name:'||CPCtargetName
    Say
    return 0
  end

Say
Say 'Obtained some or none of the CPC Info:'
Say '  uri:('||CPCuri||')'
Say '  target-name:('||CPCtargetName||')'
Say 'full response body:('||CPCInfoResponse||')'
Say
return fatalError(' ** failed to obtain CPC info **')

/*******************************************************/
/* Function:  QueryEnergy                              */
/*                                                     */
/* Retrieve attributes identified by                   */
/* EnergyAttribute stem variable                       */
/*                                                     */
/* Return 0 if successful, otherwise return -1         */
/*******************************************************/
QueryEnergy:
/* Use retrieved CPC uri to retrieve
   specific attribute properties
   GET /api/cpcs/{cpc-id}/energy-management-data
*/

if EnergyAttribute.0 < 1 then
  do
    return fatalError('** no attributes to retrieve **')
  end

EnergyQueryUri = CPCuri||'/energy-management-data'

EnergyQueryResponse = GetRequest(EnergyQueryUri, CPCtargetName)
if EnergyQueryResponse = '' Then
  do
    return fatalError('** Energy query failed **')
  end

/* Parse the response to obtain the values of the
   retrieved properties
*/
call JSON_parseJson EnergyQueryResponse

call EntryArrow

outLineCount = outLineCount + 1

do i = 1 to EnergyAttribute.0
   if EnergyAttribute.i.0 = 0 then
    do /* simple property */
      EnergyAttributeResponse = JSON_findValue2(0, EnergyAttribute.i)
      say EnergyAttribute.i||':('||EnergyAttributeResponse||')'
      if i=1 then
        REXXWRT.outLineCount = EnergyAttributeResponse
      else
        REXXWRT.outLineCount = REXXWRT.outLineCount||EnergyAttributeResponse
    end /* simple property */
   else
    do
      errMsg = '** Complex properties currently not supported (',
             ||EnergyAttribute.i||') **'
      return fatalError(errMsg)
    end /* complex property with nested content */

    if i < EnergyAttribute.0 then
      REXXWRT.outLineCount = REXXWRT.outLineCount||','

end /* i, attribute count */
call ExitArrow
return 0

/*******************************************************/
/* Function:  GetRequest                               */
/*                                                     */
/* Default to a GET of all the cpcs if no args provided*/
/* optional args:                                      */
/*     arg1 -> uri                                     */
/*     arg2 -> targetName                              */
/*                                                     */
/* On success, returns the respones body               */
/* On failure, returns an empty string                 */
/*******************************************************/
GetRequest:
drop userRequest.
drop response.

uriArg = arg(1)
targetnameArg = arg(2)

userRequest.httpmethod = HWI_REST_GET

if uriArg <> '' Then
  userRequest.uri = uriArg
else
  userRequest.uri = '/api/cpcs'

if targetnameArg <> '' Then
  userRequest.targetname = targetnameArg
else
  userRequest.targetname = ''

call EntryArrow
Say 'GET request being made....'
say 'uri:'||userRequest.uri

if userRequest.targetName <> '' Then
  say 'targetname:'||userRequest.targetName

userRequest.REQUESTBODY = ''
userRequest.CLIENTCORRELATOR = ''
userRequest.ENCODING = 0
userRequest.REQUESTTIMEOUT = 0 /* use default timeout of 60 minutes */

Address BCPII "HWIREST userRequest. response."

/* GET requests return 200 when successful */
call surfaceResponse RC, response.
call ExitArrow

if RC = 0 & response.httpStatus = 200 Then
  do
    return response.responseBody
  end
else
  return ''

/********************************************************/
/* Procedure: surfaceResponse()                         */
/*            parse through the response parm and if    */
/*            the request failed showcase the issue     */
/*                                                      */
/********************************************************/
surfaceResponse:
  say
  say 'Rexx RC: ('||arg(1)||')'

  /* continue processing even if RC <> 0
     because additional information could
     have been returned in the response.
     to help understand the error
  */
  response = arg(2)

  say 'HTTP Status: ('||response.httpstatus||')'
  successIndex = INDEX(response.httpstatus, '2')

  if successIndex = 1 then
    do /* SE responded successfully */
      say 'SE DateTime: ('||response.responsedate||')'
      say 'SE requestId: (' || response.requestId || ')'

      if response.httpstatusNum = '201' Then
        say 'Location Response: (' || response.location || ')'

      if  response.responsebody <> '' Then
        do
          Say 'Response Body: (' || response.responsebody || ')'
          return response.responsebody
        end
    end /* SE responded successfully */
  else
    do /* error path */
      say 'Reason Code: ('||response.reasoncode||')'

      if response.responsedate <> '' then
        say 'SE DateTime: ('||response.responsedate||')'

      if response.requestId <> '' Then
        say 'SE requestId: (' || response.requestId || ')'

      if response.responsebody <> '' Then
        do /* an error occurred */
          call JSON_parseJson response.responsebody

          if RESULT <> 0 then
            say 'failed to parse response'
          else
            do
              bcpiiErr=JSON_findValue(0, "bcpii-error", HWTJ_BOOLEAN_TYPE)
              if bcpiiErr = 'true' then
                say '*** BCPii generated error message:'
              else
                say '*** SE generated error message:'

              errmessage=JSON_findValue(0,"message", HWTJ_STRING_TYPE)
              say '('||errmessage||')'
              say

              say 'Complete Response Body: (' || response.responsebody || ')'
            end /* bcpii err */
        end /* response body */
    end /* error path */

 return '' /* end procedure */

/*******************************************************/
/* Function:  IncludeConstants()                       */
/* Simulate include-file functionality which REXX does */
/* not provide.  Include the constants for the product */
/* and for specific testcases via (abuse of) the       */
/* interpret instruction.                              */
/*******************************************************/
IncludeConstants:

 constantsFile.0=2
 constantsFile.1="'"||MACLIB_DATASET||"(HWICIREX)'"
 constantsFile.2="'"||MACLIB_DATASET||"(HWIC2REX)'"

 i=1
 do while i <= constantsFile.0
    call InterpretRexxFile constantsFile.i
    i=i+1
 end

 return  /* end function */

/***********************************/
/* Function:  InterpretRexxFile()  */
/***********************************/
InterpretRexxFile:
 parse arg file
 numSourceLines = 0
 rc = 0

 /**************************************/
 /* Read the lines of the designated   */
 /* (constants) rexx source file into  */
 /* a stem variable...                 */
 /**************************************/
if ISVREXX then
  do
     "ALLOC F(MYIND) DSN("||file||") SHR"
     Address MVS "EXECIO * DISKR MYIND ( FINIS STEM REXXSRC."
     "FREE F(MYIND)"
  end
else
  do
    address TSO
    "ALLOC F(MYIND) DSN("||file||") SHR REU"
    "EXECIO * DISKR MYIND ( FINIS STEM REXXSRC."
    "FREE F(MYIND)"
  end

 if rc <> 0 then
  do
    errMsg = '** fatal error, rc=('||rc,
             ||') encountered trying to read content from (',
             ||file||'), if in ISV environment, ensure you used ',
             '-I option **'
    exit fatalErrorAndCleanup(errMsg)
  end

 /**********************************/
 /* Interpret the rexx source file */
 /* line by line, to pick up the   */
 /* constants it defines...        */
 /**********************************/
 j=1
 do while j <= REXXSRC.0
    /**********************************************/
    /* Try to recognize and ignore comment lines, */
    /* interpreting all other lines...            */
    /**********************************************/
    currLine = getInterpretableRexxLine( REXXSRC.j )
    if length( currLine ) > 0 then do
       numSourceLines = numSourceLines + 1
       interpret currLine
       end
    j=j+1
    end

 return  /* end function */


/******************************************/
/* Function:  getInterpretableRexxLine()  */
/******************************************/
getInterpretableRexxLine:
 parse arg inString

 outLine = strip(inString)
 if substr(outLine,1,2) == '/*' then
    outLine = ''
 if substr(outLine,1,1) == '!' then
    outLine = ''

 return outLine  /* end function */

/**************************************************************/
/* NOTE: the following was taken from sample hwtjxrx1.rexx    */
/**************************************************************/
/******************************************************************/
/* Procedure: traverseJsonObject                                  */
/*                                                                */
/* Traverses the designated object. Traversal is accomplished by  */
/* retrieving each object entry, and invoking traverseJsonEntry   */
/* upon it.  Note that the nature of a given entry may result in  */
/* a recursive call to this procedure.                            */
/*                                                                */
/* Returns: 0 if successful, -1 if not.                           */
/******************************************************************/
traverseJsonObject: procedure  expose (PROC_GLOBALS)
 objectHandle = arg(1)
 indentLevel = arg(2)
 /*********************************************/
 /* First, determine the number of name:value */
 /* pairs in the object.                      */
 /*********************************************/
 numEntries = JSON_getNumObjectEntries(objectHandle)
 if numEntries <= 0 then
    return fatalError( '** Unable to determine num object entries **' )
 /****************************************************************/
 /* Since the REXX iteration idiom is 1-based, we iterate from 1 */
 /* until the object is exhausted or fatal error.  However the   */
 /* Parser has a different (0-based) idiom, so we adjust the     */
 /* index value accordingly when we use it.                      */
 /****************************************************************/
 do i = 1 to numEntries
    /******************************************/
    /* Retrieve the next name:value pair into */
    /* objectEntry.  stem variable            */
    /******************************************/
    objectEntry. = ''
    call JSON_getObjectEntry objectHandle, i-1
    if RESULT <> 0 then
       return fatalError( '** Unable to obtain object entry ('||i-1||') **' )
    /*********************************************************/
    /* Print the entry name (portion of the name:value pair) */
    /*********************************************************/
    say indent(objectEntry.name,indentLevel)
    /**************************************************/
    /* Print the value portion of this entry.  This   */
    /* may or may not be a simple value, so we call   */
    /* a value traversal function to handle all cases */
    /**************************************************/
    call traverseJsonEntry objectEntry.valueHandle, 2+indentLevel
    end /* endloop thru object entries */
 return 0  /* end function */


/*****************************************************************************/
/* Function: traverseJsonEntry                                               */
/*                                                                           */
/* Perform a depth-first traversal of the designated JSON entry, to          */
/* demonstrate a common means of "auto-discovering" JSON data.               */
/*                                                                           */
/* Recursion occurs when the input handle designates an array or object type */
/* When the input handle designates a primitive type (e.g, string, number,   */
/* boolean, or null type), the value is retrieved and displayed.             */
/*                                                                           */
/* Usage: This type of "auto-discovery" is especially useful when the data   */
/* is unpredictable (not guaranteed to contain particular name:value pairs). */
/*                                                                           */
/* Returns: 0 if successful, -1 if not.                                      */
/*****************************************************************************/
traverseJsonEntry: procedure  expose (PROC_GLOBALS)
 entryHandle = arg(1)
 indentLevel = arg(2)
 /*********************************************************************/
 /* To properly traverse the entry, we first must determine its type  */
 /*********************************************************************/
 entryType = JSON_getType(entryHandle)
 select
    when entryType == HWTJ_OBJECT_TYPE then
       do
       call traverseJsonObject entryHandle, 2+indentLevel
       end  /* endif object */
    when entryType == HWTJ_ARRAY_TYPE then
       do
       call traverseJsonArray entryHandle, 2+indentLevel
       end /* endif array */
    when entryType == HWTJ_STRING_TYPE then
       do
       value = JSON_getValue(entryHandle, HWTJ_STRING_TYPE)
       say indent(value,indentLevel)
       end /* endif primitive type string */
    when entryType == HWTJ_NUMBER_TYPE then
       do
       value = JSON_getValue(entryHandle, HWTJ_NUMBER_TYPE)
       say indent(value,indentLevel)
       end /* endif primitive type number */
    when entryType == HWTJ_BOOLEAN_TYPE then
       do
       value = JSON_getValue(entryHandle, HWTJ_BOOLEAN_TYPE)
       say indent(value,indentLevel)
       end /* endif primitive type boolean */
    when entryType == HWTJ_NULL_TYPE then
       do
       value = '(null)'
       say indent(value,indentLevel)
       end /* endif primitive type null */
    otherwise
       do
       /***************************************************/
       /* If we've reached this point there is a problem. */
       /***************************************************/
       return fatalError( '** unable to retrieve JSON type **' )
       end /* endif problem */
    end /* end select */
return 0  /* end function */


/******************************************************************/
/* Procedure: traverseJsonArray                                   */
/*                                                                */
/* Traverses the designated array. Traversal is accomplished by   */
/* retrieving each entry, and invoking traverseJsonEntry upon     */
/* it.  Note that the nature of a given entry may result in a     */
/* recursive call to this procedure.                              */
/*                                                                */
/* Returns: 0 if successful, -1 if not.                           */
/******************************************************************/
traverseJsonArray: procedure  expose (PROC_GLOBALS)
 arrayHandle = arg(1)
 indentLevel = arg(2)
 numEntries = JSON_getArrayDim( arrayHandle )
 if numEntries == 0 then
    do
    say '(empty array)'
    return 0
    end /* endif empty array */
 /*******************************************************/
 /* Loop, getting each array entry, and traversing it.  */
 /* Again, we must reconcile the the REXX 1-based idiom */
 /* with that of the  toolkit.                          */
 /*******************************************************/
 do i = 1 to numEntries
    entryHandle = JSON_getArrayEntry( arrayHandle, i-1 )
    call traverseJsonEntry entryHandle, 2+indentLevel
    end /* endloop thru array entries */
 return 0  /* end function */

/***********************************************/
/* Function:  indent                           */
/*                                             */
/* Return the input string prepended with the  */
/* designated number of blanks.                */
/*                                             */
/* Returns: string as described above.         */
/***********************************************/
indent:
 source = ''
 target = arg(1)
 indentSize = arg(2)
 padChar = ' '
 return insert(source,target,0,indentSize,padChar)   /* end function */


/***********************************************/
/* Function:  fatalError                       */
/*                                             */
/* Surfaces the input message, and returns     */
/* a canonical failure code.                   */
/*                                             */
/* Returns: -1 to indicate fatal script error. */
/***********************************************/
fatalError:
 errorMsg = arg(1)
 say errorMsg
 return -1  /* end function */

/***********************************************/
/* Function:  fatalErrorAndCleanup             */
/*                                             */
/* Surfaces the input message, and invokes     */
/* cleanup to ensure the parser is terminated  */
/* and HWIHOST is set to off, and returns      */
/* a canonical failure code.                   */
/*                                             */
/* Returns: -1 to indicate fatal script error. */
/***********************************************/
fatalErrorAndCleanup:
 errorMsg = arg(1)
 say errorMsg
 call Cleanup
 return -1  /* end function */

/***********************************************************/
/* Function: JSON_getValue                                 */
/*                                                         */
/* Return the value portion of the designated Json object  */
/* according to its type.  If this type indicates a        */
/* simple data value, then one of the "get value" toolkit  */
/* apis (HWTJGVAL, HWTJGBOV) is used.  If the type         */
/* an object or array, then the handle is simply echoed    */
/* back.                                                   */
/*                                                         */
/* Returns: The value of the designated entry as described */
/* above, if successful.  An empty string is returned      */
/* otherwise.                                              */
/***********************************************************/
JSON_getValue:
 entryHandle = arg(1)
 valueType = arg(2)
 /**********************************************/
 /* Get the value for a String or Number type  */
 /**********************************************/
 if valueType == HWTJ_STRING_TYPE | valueType == HWTJ_NUMBER_TYPE then
    do
    /***********************************/
    /* Call the HWTJGVAL toolkit api.  */
    /***********************************/
    ReturnCode = -1
    DiagArea. = ''
    address hwtjson "hwtjgval ",
                    "ReturnCode ",
                    "parserHandle ",
                    "entryHandle ",
                    "valueOut ",
                    "DiagArea."
    RexxRC = RC
    if JSON_isError(RexxRC,ReturnCode) then
       do
       call JSON_surfaceDiag 'hwtjgval', RexxRC, ReturnCode, DiagArea.
       say '** hwtjgval failure **'
       valueOut = ''
       end /* endif hwtjgval failed */
    return valueOut
    end  /* endif string or number type */
 /*************************************/
 /* Get the value for a Boolean type  */
 /*************************************/
 if valueType == HWTJ_BOOLEAN_TYPE then
    do
    ReturnCode = -1
    DiagArea. = ''
    /**********************************/
    /* Call the HWTJGBOV toolkit api  */
    /**********************************/
    address hwtjson "hwtjgbov ",
                    "ReturnCode ",
                    "parserHandle ",
                    "entryHandle ",
                    "valueOut ",
                    "DiagArea."
    RexxRC = RC
    if JSON_isError(RexxRC,ReturnCode) then
       do
       call JSON_surfaceDiag 'hwtjgbov', RexxRC, ReturnCode, DiagArea.
       say '** hwtjgbov failure **'
       valueOut = ''
       end /* endif hwtjgbov failed */
    return valueOut
    end  /* endif number type */
 /******************************************/
 /* Use your own discretion for NULL type  */
 /******************************************/
 if valueType == HWTJ_NULL_TYPE then
    do
    valueOut = '*null*'
    say 'Returning arbitrary '||valueOut||' for null type'
    return valueOut
    end
  /***************************************************************/
  /* To reach this point, valueType must be a non-primitive type */
  /* (i.e., either HWTJ_ARRAY_TYPE or HWTJ_OBJECT_TYPE), and we  */
  /* Simply echo back the input handle as our return value       */
  /***************************************************************/
  return entryHandle  /* end function */


/*************************************************************************/
/* Function: JSON_initParser                                             */
/*                                                                       */
/*  Create a Json parser instance via the HWTJINIT toolkit api.          */
/*  Initializes the global variable parserHandle with the handle         */
/*  returned by the api.  This handle is required by other toolkit api's */
/*  (and so this HWTJINIT api must be invoked before invoking any other  */
/*  parse-related api).                                                  */
/*                                                                       */
/* Returns: 0 if successful, -1 if not.                                  */
/*************************************************************************/
JSON_initParser:
 if VERBOSE then
    say 'Initializing Json Parser'
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
    return fatalError( '** hwtjinit failure **' )
    end  /* endif hwtjinit failure */
 /********************************/
 /* Set the all-important global */
 /********************************/
 parserHandle = handleOut
 if VERBOSE then
    say 'Json Parser init (hwtjinit) succeeded'
 PARSER_INIT = TRUE

 return 0  /* end function */


/***********************************************************************/
/* Function:  JSON_parseJson                                           */
/*                                                                     */
/*  Parse the input text body via call to the HWTJPARS toolkit api.    */
/*                                                                     */
/*  HWTJPARS builds an internal representation of the input JSON text  */
/*  which allows search, traversal, and modification operations        */
/*  against that representation.  Note that HWTJPARS does *not* make   */
/*  its own copy of the input source, and therefore the caller must    */
/*  ensure that the provided source string remains unmodified for the  */
/*  duration of the associated parser instance (i.e., if the source    */
/*  string is modified, subsequent service call behavior and results   */
/*  from the parser are unpredictable).                                */
/*                                                                     */
/* Returns:                                                            */
/*  0 if successful, -1 if not.                                        */
/***********************************************************************/
JSON_parseJson:
 jsonTextBody = arg(1)
 if VERBOSE then
    say 'Invoke Json Parser'
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
 if VERBOSE then
    say 'JSON data parsed successfully'
 return 0  /* end function */


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
 if VERBOSE then
    say 'Terminate Json Parser'
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
 if VERBOSE then
    say 'Json Parser terminated'

 return 0  /* end function */


/****************************************************************************/
/* Function: JSON_toString                                                  */
/*                                                                          */
/* Creates a single string representation of the Json parser's current      */
/* data, via call to the HWTJSERI toolkit api.  This is typically used      */
/* after having used create services to modify or insert additional JSON    */
/* data.  If an an error occurs during serialization, an empty string is    */
/* produced.                                                                */
/*                                                                          */
/* Returns: A string as described above.                                    */
/****************************************************************************/
JSON_toString:
 if VERBOSE then
    say 'Serialize Parser data'
 /***********************************/
 /* Call the HWTJSERI toolkit api.  */
 /***********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjseri ",
                 "ReturnCode ",
                 "parserHandle ",
                 "serializedDataOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjseri', RexxRC, ReturnCode, DiagArea.
    say 'Unable to serialize JSON data'
    return ''
    end /* endif hwtjseri failure */
 if VERBOSE then
    say 'JSON data serialized'
 return serializedDataOut  /* end function */


/**********************************************************/
/* Function:  JSON_findValue                              */
/*                                                        */
/* Return the value associated with the input name from   */
/* the designated Json object, via the various toolkit    */
/* api's { HWTJSRCH, HWTJGVAL, HWTJGBOV }, as appropriate.*/
/*                                                        */
/* Returns: The value of the designated entry in the      */
/* designated Json object, if found and of the designated */
/* type, or suitable failure string if not.               */
/**********************************************************/
JSON_findValue:
 objectToSearch = arg(1)
 searchName = arg(2)
 expectedType = arg(3)
 /********************************************************/
 /* Search the specified object for the specified name   */
 /********************************************************/
 if VERBOSE then
    say 'In JSON_findValue Invoke Json Search for 'searchName
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
                 "HWTJ_SEARCHTYPE_OBJECT ",
                 "searchName ",
                 "objectToSearch ",
                 "0 ",
                 "searchResult ",
                 "DiagArea."
 RexxRC = RC
 /************************************************************/
 /* Differentiate a not found condition from an error, and   */
 /* tolerate the former.  Note the order dependency here,    */
 /* at least as the called routines are currently written.   */
 /************************************************************/
 if JSON_isNotFound(RexxRC,ReturnCode) then
    return '(not found)'
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjsrch', RexxRC, ReturnCode, DiagArea.
    say '** hwtjsrch failure **'
    return ''
    end /* endif hwtjsrch failed */
 /******************************************************/
 /* Process the search result, according to type.  We  */
 /* should first verify the type of the search result. */
 /******************************************************/
 resultType = JSON_getType( searchResult )
 if resultType <> expectedType then
    do
      if VERBOSE then
        say '** Type mismatch ('||resultType||','||expectedType||') **'

      if resultType == 'HWTJ_STRING_TYPE' then
        say 'unexpected type: HWTJ_STRING_TYPE'
      else if resultType == 'HWTJ_NUMBER_TYPE' then
        say 'unexpected type: HWTJ_NUMBER_TYPE'
      else if resultType == 'HWTJ_BOOLEAN_TYPE' then
        say 'unexpected type: HWTJ_BOOLEAN_TYPE'
      else if resultType == 'HWTJ_ARRAY_TYPE' then
        say 'unexpected type: HWTJ_ARRAY_TYPE'
      else if resultType == 'HWTJ_OBJECT_TYPE' then
        say 'unexpected type: HWTJ_OBJECT_TYPE'
      else if resultType == HWTJ_NULL_TYPE then
       say 'unexpected type: HWTJ_NULL_TYPE'
      else
        say 'unexpected type: not recognized'

    return ''
    end /* endif unexpected type */
 /********************************************************/
 /* If the expected type is not a simple value, then the */
 /* search result is itself a handle to a nested object  */
 /* or array, and we simply return it as such.           */
 /********************************************************/
 if expectedType == HWTJ_OBJECT_TYPE | expectedType == HWTJ_ARRAY_TYPE then
    do
    return searchResult
    end /* endif object or array type */
 /*******************************************************/
 /* Return the located string or number, as appropriate */
 /*******************************************************/
 if expectedType == HWTJ_STRING_TYPE | expectedType == HWTJ_NUMBER_TYPE then
    do
    if VERBOSE then
       say 'Invoke Json Get Value'
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
       say '** hwtjgval failure **'
       return ''
       end /* endif hwtjgval failed */
    return result
    end /* endif string or number type */
 /****************************************************/
 /* Return the located boolean value, as appropriate */
 /****************************************************/
  if expectedType == HWTJ_BOOLEAN_TYPE then
    do
    if VERBOSE then
        say 'Invoke Json Get Boolean Value'
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
       say '** hwtjgbov failure **'
       return ''
       end /* endif hwtjgbov failed */
    return result
    end /* endif boolean type */

 /****************************************************/
 /* Return the located null value                    */
 /****************************************************/
 if resultType == HWTJ_NULL_TYPE then
    do
    if VERBOSE then
        say 'null value encountered'
    return '(null)'
    end /* endif null type */

 /**********************************************/
 /* This return should not occur, in practice. */
 /**********************************************/
 if VERBOSE then
    say '** No return value found **'
 return ''  /* end function */

/**********************************************************/
/* Function:  JSON_findValue2                             */
/*                                                        */
/* Return the value associated with the input name from   */
/* the designated Json object, via the various toolkit    */
/* api's { HWTJSRCH, HWTJGVAL, HWTJGBOV }, as appropriate.*/
/*                                                        */
/* To be used when the type is unknown and could be       */
/* either a string, number, boolean, or null.              */
/*                                                        */
/* Returns: The value of the designated entry in the      */
/* designated Json object, if found or suitable failure   */
/* string if not.                                         */
/**********************************************************/
JSON_findValue2:
 objectToSearch = arg(1)
 searchName = arg(2)

 /********************************************************/
 /* Search the specified object for the specified name   */
 /********************************************************/
 if VERBOSE then
    say 'In JSON_findValue2 Invoke Json Search for 'searchName
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
                 "HWTJ_SEARCHTYPE_OBJECT ",
                 "searchName ",
                 "objectToSearch ",
                 "0 ",
                 "searchResult ",
                 "DiagArea."
 RexxRC = RC
 /************************************************************/
 /* Differentiate a not found condition from an error, and   */
 /* tolerate the former.  Note the order dependency here,    */
 /* at least as the called routines are currently written.   */
 /************************************************************/
 if JSON_isNotFound(RexxRC,ReturnCode) then
    return '(not found)'
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjsrch', RexxRC, ReturnCode, DiagArea.
    say '** hwtjsrch failure **'
    return ''
    end /* endif hwtjsrch failed */
 /******************************************************/
 /* Process the search result, according to type.  We  */
 /* should first verify the type of the search result. */
 /******************************************************/
 resultType = JSON_getType( searchResult )

 /********************************************************/
 /* If the expected type is not a simple value, then the */
 /* search result is itself a handle to a nested object  */
 /* or array, and we simply return it as such.           */
 /********************************************************/
 if resultType == HWTJ_OBJECT_TYPE | resultType == HWTJ_ARRAY_TYPE then
    do
    say 'failed: result for '||searchName||' is object or array'
    return searchResult
    end /* endif object or array type */
 /*******************************************************/
 /* Return the located string or number, as appropriate */
 /*******************************************************/
 if resultType == HWTJ_STRING_TYPE | resultType == HWTJ_NUMBER_TYPE then
    do
    if VERBOSE then
       say 'Invoke Json Get Value'
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
       say '** hwtjgval failure **'
       return ''
       end /* endif hwtjgval failed */
    return result
    end /* endif string or number type */
 /****************************************************/
 /* Return the located boolean value, as appropriate */
 /****************************************************/
 if resultType == HWTJ_BOOLEAN_TYPE then
    do
    if VERBOSE then
        say 'Invoke Json Get Boolean Value'
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
       say '** hwtjgbov failure **'
       return ''
       end /* endif hwtjgbov failed */
    return result
    end /* endif boolean type */

 /****************************************************/
 /* Return the located null value                    */
 /****************************************************/
 if resultType == HWTJ_NULL_TYPE then
    do
    if VERBOSE then
        say 'null value encountered'
    return '(null)'
    end /* endif null type */

 /**********************************************/
 /* This return should not occur, in practice. */
 /**********************************************/
 if VERBOSE then
    say '** No return value found **'
 return ''  /* end function */

/**********************************************************/
/* Function:  JSON_findValue3                             */
/*                                                        */
/* Return the value associated with the input name from   */
/* the designated Json object, via the various toolkit    */
/* api's { HWTJSRCH, HWTJGVAL}, as appropriate.           */
/*                                                        */
/* To be used when the type is could be either a number   */
/* or a NULL.                                             */
/*                                                        */
/* Returns: The value of the designated entry in the      */
/* designated Json object, if found or suitable failure   */
/* string if not.                                         */
/**********************************************************/
JSON_findValue3:
 objectToSearch = arg(1)
 searchName = arg(2)

 /********************************************************/
 /* Search the specified object for the specified name   */
 /********************************************************/
 if VERBOSE then
    say 'In JSON_findValue3 Invoke Json Search for 'searchName
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
                 "HWTJ_SEARCHTYPE_OBJECT ",
                 "searchName ",
                 "objectToSearch ",
                 "0 ",
                 "searchResult ",
                 "DiagArea."
 RexxRC = RC
 /************************************************************/
 /* Differentiate a not found condition from an error, and   */
 /* tolerate the former.  Note the order dependency here,    */
 /* at least as the called routines are currently written.   */
 /************************************************************/
 if JSON_isNotFound(RexxRC,ReturnCode) then
    return '(not found)'
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjsrch', RexxRC, ReturnCode, DiagArea.
    say '** hwtjsrch failure **'
    return ''
    end /* endif hwtjsrch failed */
 /******************************************************/
 /* Process the search result, according to type.  We  */
 /* should first verify the type of the search result. */
 /******************************************************/
 resultType = JSON_getType( searchResult )

 if resultType == HWTJ_NUMBER_TYPE then
    do
    if VERBOSE then
       say 'Invoke Json Get Value'
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
       say '** hwtjgval failure **'
       return ''
       end /* endif hwtjgval failed */
    return result
    end /* endif number type */
 else if resultType == HWTJ_NULL_TYPE then
    do
       result = '(null)'
       return result
    end /* endif nulltype */
 else
    return fatalError( '** Unexpected entry type **' )

 return ''  /* end function - JSON_findValue3 */

/***********************************************************/
/* Function:  JSON_getType                                 */
/*                                                         */
/* Determine the Json type of the designated search result */
/* via the HWTJGJST toolkit api.                           */
/*                                                         */
/* Returns: Non-negative integral number indicating type   */
/* if successful, -1 if not.                               */
/***********************************************************/
JSON_getType:
 searchResult = arg(1)
 if VERBOSE then
    say 'Invoke Json Get Type'
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
 if VERBOSE then
    say 'Getting array dimension'
 /***********************************/
 /* Call the HWTJGNUE toolkit api.  */
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
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjgnue', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjgnue failure **' )
    end /* endif hwtjgnue failure */
 arrayDim = strip(dimOut,'L',0)
 if arrayDim == '' then
    return 0
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
 if VERBOSE then
    say 'Getting array entry'
 /***********************************/
 /* Call the HWTJGAEN toolkit api.  */
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
 if JSON_isError(RexxRC,ReturnCode) then
    do
    call JSON_surfaceDiag 'hwtjgaen', RexxRC, ReturnCode, DiagArea.
    say '** hwtjgaen failure **'
    end /* endif hwtjgaen failure */
 else
    result = handleOut
 return result  /* end function */

/*******************************************************/
/* Function:  JSON_getToolkitConstants                 */
/*                                                     */
/* Access constants used by the toolkit (for return    */
/* codes, etc), via the HWTCONST toolkit api.          */
/*                                                     */
/* Returns: 0 if toolkit constants accessed, -1 if not */
/*******************************************************/
JSON_getToolkitConstants:
 if VERBOSE then
    say 'Setting hwtcalls on'
 /***********************************************/
 /* Ensure that the toolkit host command is     */
 /* available in your REXX environment (no harm */
 /* done if already present).  Do this before   */
 /* your first toolkit api invocation.          */
 /***********************************************/
 call hwtcalls "on"
 if VERBOSE then
    say 'Including HWT Constants...'
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
 if JSON_isError(RexxRC,ReturnCode) then
     do
     call JSON_surfaceDiag 'hwtconst', RexxRC, ReturnCode, DiagArea.
     return fatalError( '** hwtconst (json) failure **' )
     end /* endif hwtconst error */
 return 0  /* end subroutine */


/*********************************************************/
/* Function: JSON_getObjectEntry                         */
/*                                                       */
/* Access the designated entry of the designated Json    */
/* object, via the HWTJGOEN toolkit api. Populate the    */
/* caller's objectEntry. stem variable with the name     */
/* portion of the entry, and the valueHandleOut returned */
/* by the api (the value designated by this handle may   */
/* be any of several types, and the caller has prior     */
/* knowledge of, or will discover, its type so that it   */
/* can make appropriate use of it).                      */
/*                                                       */
/* Returns: 0 to indicate that the objectEntry. stem     */
/* variable was successfully populated, -1 otherwise.    */
/*********************************************************/
JSON_getObjectEntry:
 objectHandle = arg(1)
 whichEntry = arg(2)
 if VERBOSE then
    say 'Get object entry ('||whichEntry||')'
 /*************************************/
 /* Invoke the HWTJGOEN api to access */
 /* the designated entry              */
 /*************************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgoen ",
                 "ReturnCode ",
                 "parserHandle ",
                 "objectHandle ",
                 "whichEntry ",
                 "nameOut ",
                 "valueHandleOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    say 'Unable to get object entry('||whichEntry||')'
    call JSON_surfaceDiag 'hwtjgoen', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjgoen failure **' )
    end /* endif hwtjgoen failure */
 objectEntry.name = nameOut
 objectEntry.valueHandle = valueHandleOut
 return 0  /* end function */


/********************************************************/
/* Function: JSON_getNumObjectEntries                   */
/*                                                      */
/* Get the number of entries for the Json object which  */
/* is designated by the input handle, via the HWTJGNUE  */
/* toolkit api.                                         */
/*                                                      */
/* Returns: Non-negative integral number of object      */
/* entries if successful, -1 if not.                    */
/********************************************************/
JSON_getNumObjectEntries:
 objectHandle = arg(1)
 if VERBOSE then
    say 'Determining number of object entries'
 /**********************************/
 /* Call the HWTJGNUE toolkit api. */
 /**********************************/
 ReturnCode = -1
 DiagArea. = ''
 address hwtjson "hwtjgnue ",
                 "ReturnCode ",
                 "parserHandle ",
                 "objectHandle ",
                 "numEntriesOut ",
                 "DiagArea."
 RexxRC = RC
 if JSON_isError(RexxRC,ReturnCode) then
    do
    say 'Unable to determine number of object entries'
    call JSON_surfaceDiag 'hwtjgnue', RexxRC, ReturnCode, DiagArea.
    return fatalError( '** hwtjgnue failure **' )
    end /* endif hwtjgnue failure */
 if VERBOSE then
    say numEntriesOut' entries were found'
 return numEntriesOut  /* end function */


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
/* otherwise.                                                */
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
/* otherwise.                                                */
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
  say
  say '*ERROR* ('||who||') at time: '||Time()
  say 'Rexx RC: '||RexxRC||', Toolkit ReturnCode: '||ToolkitRC
  if RexxRC == 0 then
     do
     say 'DiagArea.ReasonCode: '||DiagArea.HWTJ_ReasonCode
     say 'DiagArea.ReasonDesc: '||DiagArea.HWTJ_ReasonDesc
     end
  say
 return  /* end procedure */

/***********************************************/
/* Function:  GetArgs                          */
/*                                             */
/* Parse script arguments and make appropriate */
/* variable assignments, or return fatal error */
/* code via usage() invocation.                */
/*                                             */
/* Returns: 0 if successful                    */
/*          -1 if not successful               */
/***********************************************/
GetArgs:
 S = arg(1)
 argCount = words(S)

 /* require at least 2: -D <outputDataSet> */
 if argCount == 0 | argCount < 2 | argCount > 6 then
    return usage('Wrong number of arguments')

 dataSetProvided = FALSE
 i = 1
 do while i < (argCount + 1)
   localArg = word(S,i)
   if TRANSLATE(localArg) == '-I' then
     do /* -I for isvrexx */
       ISVREXX = TRUE
       i = i + 1
     end
   else if TRANSLATE(localArg) == '-V' then
     do /* -V for json verbose*/
       VERBOSE = TRUE
       i = i + 1
     end
  else if TRANSLATE(localArg) == '-C' then
    do /* -C <CPCName> */
      i = i + 1
      if i > argCount then
       return usage('-C option specified, but is missing CPC name')

      CPCname = word(S, i)
      localCPC = FALSE
      i = i + 1
    end
  else if TRANSLATE(localArg) == '-D' then
    do /* -D <data set name> */
      i = i + 1
      if i > argCount then
       return usage('-D option specified, but is missing the data set name')

      TEMP_DATASET = word(S, i)
      dataSetProvided = TRUE
      i = i + 1
    end
  else
    do
      errMsg = 'Found unsupported argument:'||localArg
      return usage(errMsg)
    end
 end /* while loop */

if dataSetProvided = FALSE then
  return usage ('Missing required data set name for output')

return 0  /* end function */

/***********************************************/
/* Function: usage                             */
/*                                             */
/* Provide usage guidance to the invoker.      */
/*                                             */
/* Returns: -1 to indicate fatal script error. */
/***********************************************/
usage:
 whyString = arg(1)
 say
 say 'USAGE: RXENRGY1 -D outputDataSet [-C CPCname] [-I] [-V]'
 say '    REQUIRED'
 say '      -D outputDataSet, fully qualified name of an existing'
 say '         partitioned data set'
 say '         If the query is successful, a member containing the'
 say '         energy information in CSV format will be stored into'
 say '         the data set.  The member will either be named LOCAL'
 say '         or the CPC name specified via the -C option'
 say '    OPTIONAL'
 say '      -C CPCname, name of the CPC to query, default if not'
 say '         specified is the LOCAL CPC'
 say '      -I Indicate running in an ISV rexx, default if not'
 say '         specified is TSO/E REXX'
 say '      -V Turn on additional verbose JSON tracing'
 say
 say 'ERROR DETAILS: ('||whyString||')'
 say

 return -1  /* end function */

/***********************************************/
/* Function:  PrepHdrRow()                     */
/*                                             */
/* Prime the header row (RXXWRT.1) for the     */
/* the output file                             */
/***********************************************/
PrepHdrRow:

if EnergyAttribute.0 < 1 then
  do
    say 'FATAL error, no attributes to write out'
    return
  end

outLineCount = 1

REXXWRT.outLineCount = 'Energy Properties'

outLineCount = outLineCount + 1

do i = 1 to EnergyAttribute.0

    if i=1 then
      REXXWRT.outLineCount = EnergyAttribute.i
    else
      REXXWRT.outLineCount = REXXWRT.outLineCount||EnergyAttribute.i
    if i < EnergyAttribute.0 then
      REXXWRT.outLineCount = REXXWRT.outLineCount||','
end


return  /* end function */

/***********************************************************************/
/* Function:  PrepEnergyAttributes()                                   */
/*                                                                     */
/* Generate EnergyAttribute stem that contains the property names      */
/* to be retrieved.                                                    */
/*                                                                     */
/* In the case where the property is a simple entity and the value     */
/* type is either a string, boolean, number set the '.0' suffix to 0.  */
/*                                                                     */
/* In the case where the property is a complex property and the value  */
/* type is an array of objects, set the '.0' suffix to 1.              */
/* Currently there are no complex properties in this data model.       */
/*                                                                     */
/***********************************************************************/
PrepEnergyAttributes:

drop EnergyAttribute.

attrI = 1
EnergyAttribute.attrI = 'cpc-power-rating'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'cpc-power-consumption'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'cpc-power-saving'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'cpc-power-saving-state'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'cpc-power-save-allowed'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'cpc-power-capping-state'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'cpc-power-cap-minimum'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'cpc-power-cap-maximum'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'cpc-power-cap-current'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'cpc-power-cap-allowed'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-rating'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-consumption'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-saving'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-saving-state'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-save-allowed'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-capping-state'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-cap-minimum'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-cap-maximum'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-cap-current'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-power-cap-allowed'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-ambient-temperature'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-exhaust-temperature'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-humidity'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-dew-point'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-heat-load'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-heat-load-forced-air'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-heat-load-water'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-maximum-potential-power'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-maximum-potential-heat-load'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'last-energy-advice-time'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-minimum-inlet-air-temperature'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-maximum-inlet-air-temperature'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-maximum-inlet-liquid-temperature'
EnergyAttribute.attrI.0 = 0
attrI = attrI + 1
EnergyAttribute.attrI = 'zcpc-environmental-class'
EnergyAttribute.attrI.0 = 0

/* total number of attributes to query */
EnergyAttribute.0 = attrI

return  /* end function */

/*************************************************/
/* Function:  foundJSONvalue()                   */
/* Return true if the content is not empty       */
/*************************************************/
foundJSONValue:
parse arg jsonValueArg

if jsonValueArg = '' | jsonValueArg = '(not found)' then
  return FALSE

return TRUE

/*************************************************/
/* Function:  EntryArrow                         */
/* Print entry arrow '--------------->'          */
/*************************************************/
EntryArrow:
say
say '--------------->'
return

/*************************************************/
/* Function:  ExitArrow                          */
/* Print entry arrow '<---------------'          */
/*************************************************/
ExitArrow:
say '<---------------'
say
return

/*************************************************/
/* Function:  WriteToFile()                      */
/* This will write out the REXXWRT stem contents */
/*************************************************/
WriteToFile:
parse arg file

RC = 0
if ISVREXX then
  do
    "ALLOC F(MYOUTD) DSN("||file||") SHR"
    Address MVS "EXECIO * DISKW MYOUTD (STEM REXXWRT. FINIS"
    return_code = RC
    "FREE F(MYOUTD)"
  end
else
  do
    Address TSO
    "ALLOC F(MYOUTD) DSN("||file||") SHR REU"
    "EXECIO * DISKW MYOUTD (STEM REXXWRT. FINIS"
    return_code = RC
    "FREE F(MYOUTD)"
  end

RC = return_code                  

if RC <> 0 then
  do
    errMsg = '** fatal error, rc=('||rc,
             ||') encountered trying to write out content **'
    return fatalError(errMsg)
  end

return  rc /* end function */

/*************************************************/
/* Function:  VerifyDataSet()                    */
/*                                               */
/* Verify the data set identified by the         */
/* userDataSet argument exists.                  */
/*                                               */
/* Return 0 if data set exists,                  */
/*          otherwise a non zero                 */
/*************************************************/
VerifyDataSet:
parse arg userDataSet

dsAvailable = ''
rc = 0
if ISVREXX then
  do
    "ALLOC F(MYOUTD) DSN("||userDataSet||") SHR"
    if rc <> 0 then
      do
        say '** fatal error, attempt to verify ('||,
                 userDataSet||') exists using ALLOC '||,
                 'resulted in ('||rc||')'

      end
    else
      do
        "FREE F(MYOUTD)"
      end
  end
else
  do
    dsAvailable = SYSDSN("'"userDataset"'")
    if dsAvailable <> "OK" then
      do
        errMsg = '** fatal error, attempt to verify ('||,
                 userDataSet||') exists resulted in ('||dsAvailable||')'
        return fatalError(errMsg)
      end
  end
return  rc /* end function */
