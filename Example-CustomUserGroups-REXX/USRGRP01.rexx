/* REXX */
/* Start of Specifications ********************************************
 * Beginning of Copyright and License
 *
 * Copyright 2022 IBM Corp.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
 * either express or implied.  See the License for the specific
 * language governing permissions and limitations under the License.
 *
 * End of Copyright and License
 **********************************************************************
 *
 * Script Name: USRGRP01
 *
 * Description:
 *   Sample REXX code which uses HWIREST API to take various actions
 *   against a CPC's Custom User Groups. This sample can query the
 *   target CPC's Custom User Groups and their members. Additionally,
 *   remove a target LPAR from a Custom User Group and add a target
 *   LPAR to a Custom User Group.
 *
 * Operation:
 *
 *  Code flow in this sample:
 *
 *    1.  Parse the argument string specified by a user for the
 *        the following:
 *          a. The target CPC
 *          b. The target LPAR
 *          c. The target Custom User Group if specified
 *          d. The action to take on the Custom User Group if specified
 *
 *    2.  Retrieve the target CPC's related information
 *
 *    3.  Retrieve the target LPAR's related information
 *
 *    4.  Query the CPC for a list of all Custom User Groups
 *
 *      4a. If a user specified the target user group then the sample
 *          will attempt to find the target user group from the list
 *          of target user groups.
 *
 *      4b. If the sample cannot find the target user group or is
 *          missing the target user group parm then an error message
 *          will be displayed. In addition, the usage information of the
 *          sample will be displayed along with the current Custom User
 *          Groups on the CPC
 *
 *    5.  Using the target user group's information, query the current
 *        members of the target user group. The sample will display a
 *        list of the current members along with their corresponding
 *        URIs.
 *
 *    6.  Now depending on the action specified the sample will do one
 *        of the following steps
 *
 *      6a. If no action argument was specified then the sample will
 *          return
 *
 *      6b. If any failures occurred when adding or removing the target
 *          LPAR then the sample will display the error messages and
 *          exit
 *
 *      6c. If the ADD action argument was specified, the sample will
 *          attempt to add the target LPAR to the target user group. If
 *          the REMOVE action argument was specified, the sample will
 *          attempt to remove the target LPAR from the target user
 *          group. The sample will then fetch and display an updated
 *          list of the user group members if the ADD or REMOVE action
 *          was specified
 *
 *    7.  The sample will cleanup and exit
 *
 * Invocation:
 *
 *  USRGRP01 [-C CPCName] [-L LPARName] [-G CustomUserGroup]
 *           [-A Action {ADD, REMOVE}] [-I] [-V]
 *
 *  Optional Input Parameters:
 *    CPCName  - The name of the CPC to query, default is local CPC
 *    LPARName - The name of the LPAR to query and target, default is
 *               the local LPAR
 *    UserGroupName - The name of the Custom User Group to target
 *    Action        - The action to take against the Custom User Group
 *                    limited to ADD or REMOVE
 *    -I            - indicate running in ISV REXX environment, default
 *                    is TSO/E
 *    -V            - turn on additional verbose JSON tracing
 *
 *
 *  List all Custom User Groups:
 *
 *    Local CPC and LPAR:
 *     ex 'HWI.USER.REXX(USRGRP01)'
 *
 *    Remote CPC and LPAR:
 *     ex 'HWI.USER.REXX(USRGRP01)' '-C CPC1 -L LPAR1'
 *
 *  Lists the members of the TEST Custom User Group:
 *
 *    Local CPC and LPAR:
 *     ex 'HWI.USER.REXX(USRGRP01)' '-G TEST'
 *
 *    Remote CPC and LPAR:
 *     ex 'HWI.USER.REXX(USRGRP01)' '-C CPC1 -L LPAR1 -G TEST'
 *
 *  Add the target local LPAR to the TEST Custom User Group
 *
 *    Local CPC and LPAR:
 *     ex 'HWI.USER.REXX(USRGRP01)' '-G TEST -A ADD'
 *
 *    Remote CPC and LPAR:
 *     ex 'HWI.USER.REXX(USRGRP01)' '-C CPC1 -L LPAR1 -G TEST -A ADD'
 *
 *  Remove the target local LPAR from the TEST Custom User Group
 *
 *    Local CPC and LPAR:
 *     ex 'HWI.USER.REXX(USRGRP01)' '-G TEST -A REMOVE'
 *
 *    Remote CPC and LPAR:
 *     ex 'HWI.USER.REXX(USRGRP01)' '-C CPC1 -L LPAR1 -G TEST -A REMOVE'
 *
 * Dependencies:
 *
 *  None
 *
 * Notes:
 *
 *  None
 *
 * Reference:
 *   See the z/OS MVS Programming: Callable Services for
 *   High-Level Languages publication for more information
 *   regarding the usage of HWIREST and JSON Parser APIs.
 *
 *
 * End of Specifications **********************************************/

/**********************************************************************
 *                       REXX Script Constants
 **********************************************************************/
MACLIB_DATASET = 'SYS1.MACLIB'
TRUE = 1
FALSE = 0

CUSTOM_USR_GRPS_BASE_URI = '/api/groups'

/**********************************************************************
 *                       Global Variables
 **********************************************************************/
/* JSON parser specific, enabled via -v */
VERBOSE = FALSE

hwiHostRC = 0
HWIHOST_ON = FALSE

/* default to TSO/E, enable via -I */
ISVREXX = FALSE
PARSER_INIT = FALSE

/*
 * CPC globals
 */
CPCname = ""
CPCuri = ""
CPCtargetName = ""
localCPC = TRUE

/*
 * LPAR globals
 */
LPARname = ""
lparURI = ""
lparTargetName = ""
localLPAR = TRUE

/*
 * Misc. globals
 */
targetUserGroup = ""
isMissingTargetGroup = TRUE

addLPARToCustomUserGroup = FALSE
removeLPARFromCustomUserGroup = FALSE

parserHandle = ""

customUserGroups. = 0
customUserGroupMems. = 0

/**********************************************************************
 *                       Initial Entry Point
 **********************************************************************/
Parse Arg arguments
Return Main(arguments)

/**********************************************************************
 *                       Main Function begins
 **********************************************************************/
Main:
  argString = Arg(1)

  /********************************************************************
   * Get the arguments specified by the user
   ********************************************************************/
  If GetArgs(argString) <> 0 Then
    Exit -1

  Say 'Starting LSTGRPS for CPC name:' || CPCname ||,
      ' and Customer User Group name:' || targetUserGroup

  If ISVREXX Then Do
    Say 'Running in an ISV REXX environment'

    hwiHostRC = hwihost("ON")
    Say 'HWIHOST("ON") return code is :(' || hwiHostRC || ')'

    If hwiHostRC <> 0 Then
      Exit FatalErrorAndCleanup('Unable to turn on HWIHOST')

    HWIHOST_ON = TRUE
  End

  /********************************************************************
   * Include the constants for the JSON parser and MACLIB BCPii
   * constants
   ********************************************************************/
  Call IncludeConstants
  Call GetJSONToolkitConstants

  If RESULT <> 0 Then
    Exit FatalErrorAndCleanup('Environment error')

  PROC_GLOBALS = 'VERBOSE parserHandle ' || HWT_CONSTANTS

  /********************************************************************
   * Create a new parser instance
   ********************************************************************/
  Call InitJSONParser
  If RESULT <> 0 Then
    Exit FatalErrorAndCleanup( 'Parser init failure' )

  /********************************************************************
   * Grab the CPC Information
   ********************************************************************/
  If localCPC Then Do
    If GetLocalCPCInfo() <> TRUE Then
      Exit FatalErrorAndCleanup( 'Failed to get local CPC info' )
    End
  Else Do
    If GetCPCInfo() <> TRUE Then
      Exit FatalErrorAndCleanup( 'Failed to get CPC info' )
  End

  /********************************************************************
   * Grab the LPAR Information
   ********************************************************************/
  If localLPAR Then Do
    If GetLocalLPARInfo(CPCuri, CPCtargetName) <> TRUE Then
      Exit FatalErrorAndCleanup( 'Failed to get local LPAR info' )
    End
  Else Do
    If GetLPARInfo(CPCuri, CPCtargetName, LPARname) <> TRUE Then
      Exit FatalErrorAndCleanup( 'Failed to get LPAR info' )
  End

  /********************************************************************
   * Get the Target Custom User Group URI
   ********************************************************************/
  didRetrieveMembers = GetCustomUserGroups(CPCtargetName)

  targetUserGroupURI = GetTargetCustomUserGroupURI(,
    targetUserGroup,,
    isMissingTargetGroup,
  )

  /********************************************************************
   * Verify the Custom User Group Members
   ********************************************************************/
  didRetrieveMembers = GetCustomUserGroupMembers(,
    CPCtargetName,,
    targetUserGroupURI,
  )

  /********************************************************************
    * Remove the target LPAR from the Custom User Group if specified
    *******************************************************************/
  If removeLPARFromCustomUserGroup == TRUE Then Do
    Say 'Removing target LPAR from Custom User Group'
    removedLPARFromGroup = RemoveGroupMember(,
      targetUserGroupURI,,
      lparURI,,
      CPCtargetName,
    )
  End
  /********************************************************************
   * Add the target LPAR to the Custom User Group
   ********************************************************************/
  Else If addLPARToCustomUserGroup == TRUE Then Do
    Say 'Adding new member to the Custom User Group'
    addedNewGroupMember = AddNewGroupMember(,
      targetUserGroupURI,,
      lparURI,,
      CPCtargetName,
    )
  End

  If (,
    removeLPARFromCustomUserGroup == TRUE |,
    addLPARToCustomUserGroup == TRUE,
  ) Then Do
    /*
     * Verify the action was taken to either add or remove the LPAR
     * from the target user group
     */
    didRetrieveMembers = GetCustomUserGroupMembers(,
      CPCtargetName,,
      targetUserGroupURI,
    )
  End

  Call Cleanup

Return 0

/**********************************************************************
 * Function: GetArgs
 *
 * Purpose: Parse user's arguments and set the appropriate global
 *          variables
 *
 * Input: ARG_STR - The string representation of the arguments passed
 *                  to the REXX script by the user
 *
 * Output: An Integer indicating if function was successful
 *         (0 if successful, -1 if not.)
 *
 * Side-Effects:
 *
 *  1. Calls the Usage helper function to display the script's expected
 *     Usage. This Usage helper function returns a -1
 *  2. Successful parsing of the user's arguments will set the
 *     appropriate global variables
 *
 **********************************************************************/
GetArgs:

  MAX_NUM_OF_ARGS = 10

  ARG_STR = Arg(1)

  argCount = Words(ARG_STR)

  If argCount > MAX_NUM_OF_ARGS Then
    Return Usage( 'Wrong number of arguments' )

  Do i = 1 to argCount
    userArg = Word(ARG_STR, i)

    If Translate(userArg) == '-C' Then Do
      i = i + 1

      If i > argCount Then Do
        Return Usage('-C option specified, but is missing CPC name')
      End

      CPCname = Word(ARG_STR, i)
      localCPC = False

    End
    Else If Translate(userArg) == '-L' Then Do
      i = i + 1

      If i > argCount Then Do
        Return Usage('-L option specified, but is missing LPAR name')
      End

      LPARname = Word(ARG_STR, i)
      localLPAR = False

    End
    Else If Translate(userArg) == '-G' Then Do
      i = i + 1

      If i > argCount Then Do
        Return Usage(,
          '-G option specified, but is missing Custom User Group',
        )
      End

      targetUserGroup = Word(ARG_STR, i)
      isMissingTargetGroup = FALSE

    End
    Else If Translate(userArg) == '-A' Then Do
      i = i + 1

      If i > argCount Then Do
        Return Usage(,
          '-A option specified, but is missing an Action to take',
        )
      End

      /*
       * Convert the fourth argument (ADD or REMOVE) to uppercase for
       * a user's convenience
       */
      optionSpecified = Translate(Word(ARG_STR, i))

      If optionSpecified == 'ADD' Then Do
        addLPARToCustomUserGroup = TRUE
      End
      Else If optionSpecified == 'REMOVE' Then Do
        removeLPARFromCustomUserGroup = TRUE
      End
      Else Do
        argErr = 'Unrecognized action to take against the target ',
                 'user group (' || Word(ARG_STR, i) || ')'
        Return Usage(argErr)
      End
    End
    Else If Translate(userArg) == '-V' Then Do
      VERBOSE = TRUE
    End
    Else If Translate(userArg) == '-I' Then Do
      ISVREXX = TRUE
    End
    Else Do
      argErr = 'Unrecognized argument ('||userArg||')'
      Return Usage(argErr)
    End
  End

Return 0

/**********************************************************************
 * Function: IncludeConstants
 *
 * Purpose: Simulate include-file functionality which REXX does
 *          not provide. Include the constants for the product
 *          and for specific testcases via the interpret instruction.
 *
 * Input: None
 *
 * Output: None
 *
 * Side-Effects:
 *
 *  1. Reads and includes the constants stored in the HWICIREX and
 *     HWIC2REX SYS1.MACLIB members
 *
 **********************************************************************/
IncludeConstants:

  constantsFile.0=2
  constantsFile.1="'" || MACLIB_DATASET || "(HWICIREX)'"
  constantsFile.2="'" || MACLIB_DATASET || "(HWIC2REX)'"

  i=1
  Do While i <= constantsFile.0
    Call InterpretRexxFile constantsFile.i
    i=i+1
  End

Return

/**********************************************************************
 * Function: InterpretRexxFile
 *
 * Purpose: Reads the specified REXX file and interprets each indvidual
 *          line specified within the REXX file (By interpret we mean
 *          read and execute the REXX source file line if it is valid
 *          and is not a comment)
 *
 * Input: file - The valid REXX file to read and interpret
 *
 * Output: None
 *
 * Side-Effects:
 *
 *  1. Reads the specified file and interprets the REXX source file line
 *
 **********************************************************************/
InterpretRexxFile:

  rc = 0

  /********************************************************************
   * Read the specified file according the REXX environment we are in
   * and store the REXX source lines in the REXXSRC stem variable
   ********************************************************************/
  Parse Arg file

  If ISVREXX Then Do
    "ALLOC F(MYIND) DSN(" || file || ") SHR"
    Address MVS "EXECIO * DISKR MYIND ( FINIS STEM REXXSRC."
    "FREE F(MYIND)"
  End
  Else Do
    Address TSO
    "ALLOC F(MYIND) DSN(" || file || ") SHR REU"
    "EXECIO * DISKR MYIND ( FINIS STEM REXXSRC."
    "FREE F(MYIND)"
  End

  If rc <> 0 Then Do
    errMsg = 'RC = (' || rc ||,
             ') encountered trying to read content from (', || file ||,
             '), if in ISV environment, ensure you used ',
             '-I option'
    Exit FatalErrorAndCleanup(errMsg)
  End

  /********************************************************************
   * Interpret the REXX source file line by line, to pick up the
   * constants it defined in the REXX source file. In order to speed
   * up the processing of the REXX source file we interpret two REXX
   * lines at each iteration from the beginning and end of the REXX
   * source file lines
   ********************************************************************/
  bgnLineIdx = 1
  endLineIdx = REXXSRC.0

  Do While endLineIdx >= bgnLineIdx
    /******************************************************************
     * Try to recognize and ignore comment lines while interpreting all
     * other lines
     ******************************************************************/
    currLine = GetInterpretableRexxLine( REXXSRC.bgnLineIdx)

    If length( currLine ) > 0 Then Do
      Interpret currLine
    End

    currLine = GetInterpretableRexxLine( REXXSRC.endLineIdx)

    If length( currLine ) > 0 Then Do
      Interpret currLine
    End

    bgnLineIdx = bgnLineIdx + 1
    endLineIdx = endLineIdx - 1
  End

Return

/**********************************************************************
 * Function: GetInterpretableRexxLine
 *
 * Purpose: Strips the specified REXX source line of whitespace and
 *          attempts to ignore any line designated as a REXX comment
 *
 * Input: orgRexxSourceLine - The original REXX source line
 *
 * Output: rexxSourceLine - A modified version of the REXX source line
 *                          containing no whitespace
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetInterpretableRexxLine:
  Parse Arg orgRexxSourceLine

  rexxSourceLine = Strip(orgRexxSourceLine)
  If SubStr(rexxSourceLine,1,2) == '/*' Then
    rexxSourceLine = ''
  If SubStr(rexxSourceLine,1,1) == '!' Then
    rexxSourceLine = ''

Return rexxSourceLine

/**********************************************************************
 *                     BCPii Helper Functions
 **********************************************************************/

/**********************************************************************
 * Function: GetLocalCPCInfo
 *
 * Purpose: Retrieve the uri and target name associated with the local
 *          CPC, prime CPCuri, and CPCtargetName variables with the info
 *
 * Input: None
 *
 * Output: Returns a boolean indicating whether the function was
 *         sucessful or not (1 is true, 0 is false)
 *
 * Side-Effects:
 *
 *  1. Sets the CPCname, CPCuri, and CPCtargetName global variables
 *
 **********************************************************************/
GetLocalCPCInfo:

  /* Assume true */
  methodSuccess = 1
  localCPCfound = FALSE

  /* First list the cpcs, then retrieve local
   * CPC which will have
   *        "location":"local"
   *
   * GET /api/cpcs
   *
   * v1: HWILIST(HWI_LIST_LOCAL_CPC)
   */
  reqUri = '/api/cpcs'
  CPCInfoResponse = GetRequest(reqUri)

  If CPCInfoResponse = '' Then Do
    Say 'Failed to retrieve CPC info **'
    Return 0
  End

  /* Parse the response to obtain the uri
   * and target name associated with CPC,
   * which will be used to query storage info
   */
  Call ParseJSONData CPCInfoResponse
  CPCArray = FindJSONValue(0, "cpcs", HWTJ_ARRAY_TYPE)

  If WasJSONValueFound(CPCArray) = FALSE Then Do
    Say 'Failed to retrieve CPCs **'
    Return 0
  End

  /*********************************************************************
   * Determine the number of CPCs represented in the array
   ********************************************************************/
  CPCs = GetJSONArrayDim(CPCArray)
  If CPCs <= 0 Then
    Return FatalError('Failed retrieving number of array entries')

  /*********************************************************************
   * Traverse the CPCs array to populate CPCsList.
   * We use the REXX (1-based) idiom  but adjust for the differing
   * (0-based) idiom of the toolkit.
   ********************************************************************/
  Say 'Processing information for ' || CPCs ||,
      ' CPC(s)... searching for local'

  Do i = 1 To CPCs
    nextEntryHandle = GetJSONArrayEntry(CPCArray,i-1)
    CPClocation = FindJSONValue(,
      nextEntryHandle,,
      "location",,
      HWTJ_STRING_TYPE,
    )

    If CPClocation = 'local' Then Do

      Say 'Found local CPC'

      If localCPCfound <> FALSE Then Do
        Say 'Error: Found two local CPCs **'
        Return 0
      End

      localCPCfound = TRUE

      CPCuri = FindJSONValue(,
        nextEntryHandle,,
        "object-uri",,
        HWTJ_STRING_TYPE,
      )

      If WasJSONValueFound(CPCuri) = FALSE Then Do
        Say 'Failed to obtain CPC URI'
        Return 0
      End

      CPCtargetName = FindJSONValue(,
        nextEntryHandle,,
        "target-name",,
        HWTJ_STRING_TYPE,
      )

      If WasJSONValueFound(CPCtargetName) = FALSE Then Do
        Say 'Failed to obtain CPC target name'
        Return 0
      End

      CPCname = FindJSONValue(,
        nextEntryHandle,,
        "name",,
        HWTJ_STRING_TYPE,
      )
      If WasJSONValueFound(CPCname) = FALSE Then Do
        Say 'Failed to obtain CPC name'
        Return 0
      End
    End
  End

  If localCPCfound = FALSE Then Do
    methodSuccess = FALSE
    Say 'Failed to retrieve local CPC info'
  End
  Else Do
    Say
    Say 'Successfully obtained local CPC Info:'
    Say '  name:' || CPCname
    Say '  uri:' || CPCuri
    Say '  target-name:' || CPCtargetName
    Say
  End

Return methodSuccess

/**********************************************************************
 * Function: GetCPCInfo
 *
 * Purpose: Retrieve the uri and target name associated with CPCname
 *          and prime CPCuri and CPCtargetName variables with the info
 *
 * Input: None
 *
 * Output: Returns a boolean indicating whether the function was
 *         sucessful or not (1 is true, 0 is false)
 *
 * Side-Effects:
 *
 *  1. Sets the CPCname, CPCuri, and CPCtargetName global variables
 *
 **********************************************************************/
GetCPCInfo:
  /* assume true */
  methodSuccess = 1
  emptyCPCResponse = '{"cpcs":[]}'

  /* First list the cpcs, filtering the response for
   * just information regarding CPC
   *
   * GET /api/cpcs?name=CPCname
   *
   * v1: HWICONN(HWI_CPC,IBM390PS.CPC)
   *
   * NOTE:
   *   If you wanted to obtain information for the 'local'
   *   CPC, then you'd retrieve the full list and search for
   *   the CPC with the "location":"local"
   *   attribute, this would be equivalent to HWICONN(HWI_CPC,*)
   */
  reqUri = '/api/cpcs?name=' || CPCname
  CPCInfoResponse = GetRequest(reqUri)

  emptyCPCArray = INDEX(CPCInfoResponse, emptyCPCResponse)
  If emptyCPCArray > 0 | CPCInfoResponse = '' Then Do
    Say 'Failed to get CPC info'
    Return 0
  End

  /* Parse the response to obtain the uri
   * and target name associated with CPC,
   * which will be used to query storage info
   */
  Call ParseJSONData CPCInfoResponse

  CPCuri = FindJSONValue(0,"object-uri", HWTJ_STRING_TYPE)
  If CPCuri = '' Then
    methodSuccess = 0

  CPCtargetName = FindJSONValue(0,"target-name", HWTJ_STRING_TYPE)
  If CPCtargetName = '' Then
    methodSuccess = 0

  If methodSuccess Then Do
    Say
    Say 'Successfully obtained CPC Info:'
    Say '  uri:' || CPCuri
    Say '  target-name:' || CPCtargetName
    Say
  End
  Else Do
    Say
    Say 'Obtained some or none of the CPC Info:'
    Say '  uri:('||CPCuri||')'
    Say '  target-name:('||CPCtargetName||')'
    Say 'full response body:('||CPCInfoResponse||')'
    Say
    Say 'Failed to obtain CPC info'
    Say
  End

Return methodSuccess

/**********************************************************************
 * Function:  GetLPARInfo
 *
 * Purpose: Retrieve the uri and target name associated with an LPAR
 *          that exists on CPC and prime lparURI and lparTargetName
 *          variables with the info
 *
 * Input: TARGET_CPC_URI   - The CPC URI to target
 *        TARGET_CPC_NAME  - The name of the CPC to target
 *        TARGET_LPAR_NAME - The name of the LPAR to target
 *
 * Output: A boolean indicating whether the request to retrieve the
 *         LPAR Information was successful (1 is successful, 0 is
 *         failed)
 *
 * Side-Effects:
 *
 *  1. Sets the lparURI and lparTargetName variables with the
 *     appropriate lpar information
 *
 **********************************************************************/
GetLPARInfo:

  TARGET_CPC_URI = Arg(1)
  TARGET_CPC_NAME = Arg(2)
  TARGET_LPAR_NAME = Arg(3)

  /*
   * Assume true
   */
  methodSuccess = 1
  emptyLPARResponse = '{"logical-partitions":[]}'

  /*
   * First list all the LPARS on CPC, filtering the response
   * for information specific to LPAR:
   * /api/cpcs/{cpc-id}/logical-partitions?name=LPAR
   *
   * v1:HWICONN(HWI_IMAGE,IBM390PS.CPC.LPAR)
   *
   * NOTE:
   *
   *  If you want to obtain information for the 'local'LPAR, then
   *  you retrieve the full list and search for the LPAR with the
   *  "request-origin":true attribute, this would be equivalent to
   *  HWICONN(HWI_LIST,*)
   */
  listLPARURI = TARGET_CPC_URI || '/logical-partitions?name='||,
                TARGET_LPAR_NAME
  LPARInfoResponse = GetRequest(listLPARURI, TARGET_CPC_NAME)

  emptyLPARArray = Index(LPARInfoResponse, emptyLPARResponse)

  If emptyLPARArray > 0 | LPARInfoResponse = '' Then Do
    Say 'Failed to get LPAR '|| TARGET_LPAR_NAME ||,
        ' info'
    Return 0
  End

  /*
   * Parse the response to obtain the uri and target name associated
   * with the CPC, which will be used to query storage info
   */
  Call ParseJSONData LPARInfoResponse

  lparURI = FindJSONValue(0, "object-uri", HWTJ_STRING_TYPE)

  If lparURI = '' Then
    methodSuccess = 0

  lparTargetName = FindJSONValue(0, "target-name", HWTJ_STRING_TYPE)
  If lparTargetName = '' Then
    methodSuccess = 0

  If methodSuccess Then Do
    Say
    Say 'Successfully obtained LPAR Info:'
    Say '  uri:' || lparURI
    Say '  target-name:' || lparTargetName
    Say
  End
  Else Do
    Say
    Say 'Obtained some or none of the LPAR Info:'
    Say '  uri:(' || lparURI || ')'
    Say '  target-name:(' || lparTargetName || ')'
    Say 'full response body:(' || LPARInfoResponse || ')'
    Say
    Say 'Failed to obtain LPAR info'
  End

Return methodSuccess

/**********************************************************************
 * Function:  GetLocalLPARInfo
 *
 * Purpose: Retrieve the uri and target name associated with local LPAR
 *          prime lparURI and lparTargetName variables with the info
 *
 *
 * Input: TARGET_CPC_URI   - The CPC URI to target
 *        TARGET_CPC_NAME  - The name of the CPC to target
 *
 * Output: A boolean indicating whether the request to retrieve the
 *         LPAR Information was successful (1 is successful, 0 is
 *         failed)
 *
 * Side-Effects:
 *
 *  1. Sets the lparURI and lparTargetName variables with the
 *     appropriate lpar information
 *
 **********************************************************************/
GetLocalLPARInfo:

  TARGET_CPC_URI = Arg(1)
  TARGET_CPC_NAME = Arg(2)

  /*
   * Assume true
   */
  methodSuccess = TRUE
  localLPARfound = FALSE

  /*
   * First list the LPAR, then retrieve local LPAR which will have
   * “request-origin” : true
   *
   * GET /api/cpcs/{cpc-id}/logical-partitions
   *
   * v1: HWILIST(HWI_LIST_LOCALIMAGE)
   */
  lparURI = TARGET_CPC_URI || '/logical-partitions'
  LPARInfoResponse = GetRequest(lparURI, TARGET_CPC_NAME)

  If LPARInfoResponse = '' Then Do
    Say 'Failed to get local LPAR info'
    Return 0
  End

  Call ParseJSONData LPARInfoResponse

  LPARArray = FindJSONValue(0, "logical-partitions", HWTJ_ARRAY_TYPE)

  If WasJSONValueFound(LPARArray) = FALSE Then Do
    Say 'Failed to retrieve LPARs'
    Return 0
  End

  /*
   * Determine the number of LPARs represented in the array
   */
  LPARs = GetJSONArrayDim(LPARArray)

  If LPARs <= 0 Then
    Return FatalError(,
      'Unable to retrieve number of array entries',
    )

  /********************************************************************
   * Traverse the LPARs array to populate LPARsList.
   * We use the REXX (1-based) idiom  but adjust for the differing
   * (0-based) idiom of the toolkit.
   ********************************************************************/
  Say 'Processing information for ' || LPARs ||,
      ' LPAR(s)... searching for local'

  Do i = 1 To LPARs
    nextEntryHandle = GetJSONArrayEntry(LPARArray,i-1)

    LPARlocal = FindJSONValue(,
      nextEntryHandle,,
      "request-origin",,
      HWTJ_BOOLEAN_TYPE,
    )

    If LPARlocal = 'true' Then Do
      Say 'Found local LPAR'

      If localLPARfound <> 0 Then Do
        Say 'Found two local LPARs'
        Return 0
      End
      localLPARfound = TRUE

      lparURI = FindJSONValue(,
        nextEntryHandle,,
        "object-uri",,
        HWTJ_STRING_TYPE,
      )

      If WasJSONValueFound(lparURI) = FALSE Then Do
        Say 'Failed to obtain LPAR URI'
        Return 0
      End

      lparTargetName = FindJSONValue(,
        nextEntryHandle,,
        "target-name",,
        HWTJ_STRING_TYPE,
      )

      If WasJSONValueFound(lparTargetName) = FALSE Then Do
        Say '**failed to obtain LPAR target name**'
        Return 0
      End

      LPARname = FindJSONValue(,
        nextEntryHandle,,
        "name",,
        HWTJ_STRING_TYPE,
      )

      If WasJSONValueFound(LPARname) = FALSE Then Do
        Say '**failed to obtain LPAR name**'
        Return 0
      End
    End
  End

  If localLPARfound = FALSE Then Do
    methodSuccess = FALSE
    Say 'Failed to retrieve local LPAR info'
  End
  Else Do
    Say
    Say 'Successfully obtained local LPAR Info:'
    Say '  name:' || LPARname
    Say '  uri:' || lparURI
    Say '  target-name:' || lparTargetName
    Say
  End

Return methodSuccess

/**********************************************************************
 * Function: GetCustomUserGroups
 *
 * Purpose: Retrieve the custom user groups visible to this user
 *
 * Input: TARGET - The target object to retrieve the custom user groups
 *                 on
 *
 * Output: A stem tail variable where the variable's values correspond
 *         to the following:
 *
 *         customUserGroups.0 = N number of custom user groups
 *         customUserGroups.<Custom_Group_Name1> = <Custom_Group_URI1>
 *         customUserGroups.<Custom_Group_Name2> = <Custom_Group_URI2>
 *         ...
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetCustomUserGroups:

  GROUPS_LIST_KEY = 'groups'
  GROUP_NAME_KEY = 'name'
  GROUP_URI_KEY = 'object-uri'

  TARGET = Arg(1)

  customUserGrpResponse = GetRequest(,
    CUSTOM_USR_GRPS_BASE_URI,,
    TARGET,
  )

  If customUserGrpResponse = '' Then Do
    Say 'Failed to find Custom User Groups **'
    Exit 0
  End

  Call ParseJSONData customUserGrpResponse

  /*
   * Attempt to find the list of custom groups available to this user
   */
  groupsList = FindJSONValue(0, GROUPS_LIST_KEY, HWTJ_ARRAY_TYPE)

  If WasJSONValueFound(groupsList) = FALSE Then Do
    Return FatalError(' ** Failed to retrieve Custom User Groups ** ')
  End

  numOfCustUsrGrps = GetJSONArrayDim(groupsList)
  If numOfCustUsrGrps <= 0 Then Do
    Exit FatalError('Error: No Custom User Groups found')
  End

  /********************************************************************
   * Traverse the list of custom user groups to populate the STEM
   * variables. We use the REXX (1-based) idiom  but adjust for the
   * differing (0-based) idiom of the toolkit.
   ********************************************************************/
  Say 'Processing the ' || numOfCustUsrGrps ||,
      ' number of custom user groups'

  Drop customUserGroups.

  Do grpIdx = 1 to numOfCustUsrGrps

    /*
     * Grab the next entry within the Custom Groups List
     */
    nextGroupEntry = GetJSONArrayEntry(groupsList, grpIdx - 1)

    customUsrGrpName = FindJSONValue(,
      nextGroupEntry,,
      GROUP_NAME_KEY,,
      HWTJ_STRING_TYPE,
    )

    If WasJSONValueFound(customUsrGrpName) = FALSE Then Do
      Say ' ** Failed to find Custom User Group name ** '
      Return 0
    End

    customUsrGrpURI = FindJSONValue(,
      nextGroupEntry,,
      GROUP_URI_KEY,,
      HWTJ_STRING_TYPE,
    )

    If WasJSONValueFound(customUsrGrpURI) = FALSE Then Do
      Say ' ** Failed to find Custom User Group URI ** '
      Return 0
    End

    customUserGroups.customUsrGrpName = customUsrGrpURI

    Say 'Custom User Group Name: ' ||,
        customUsrGrpName ||,
        ' | URI: ' ||,
        customUserGroups.customUsrGrpName
  End

  customUserGroups.0 = numOfCustUsrGrps

Return 0

/**********************************************************************
 * Function: GetTargetCustomUserGroupURI
 *
 * Purpose: Retrieve the specified custom user group URI
 *
 * Input: targetedUserGroup   - The name of the custom user group to
 *                              target
 *        missingTargetGroup  - A boolean indicating whether the
 *                              target Custom Group parm was
 *                              missing in the scripts args
 *
 * NOTE: You might be asking why does the missingTargetGroup
 *       parm exist? Well it boils down to the order of execution
 *       within the script. Since a first time user may or may not
 *       know the name of the Custom User Groups, we ensured an error
 *       will be thrown but after the user has the opportunity to review
 *       the Custom User Groups defined on the target CPC.
 *
 * Output: A string containing the URI of the target CPC Custom User
 *         Group
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetTargetCustomUserGroupURI:

  targetedUserGroup = Arg(1)
  missingTargetGroup = Arg(2)

  /*
   * There are two potential checks we want to ensure before attempting
   * to fetch the Custom User Group URI:
   *
   * 1. We want to check if a target group was specified. If no target
   *    group was specified then we simply wish to exit the sample
   *    since the sample was designed to handle the missing parm.
   *
   * 2. We want to ensure the Custom User Group exists on the CPC. If it
   *    does not exit then we want to throw an error, display the usage
   *    of the sample, and exit the sample gracefully.
   */
  If missingTargetGroup == TRUE Then Do
    Exit 0
  End
  Else If (,
    Symbol('customUserGroups.' || targetedUserGroup) <> 'VAR',
  ) Then Do
    Call Usage
    Say
    Exit FatalErrorAndCleanup(,
      'The Custom Group target is not valid. Please verify the '||,
      'target group was specified and exists.',
    )
  End

Return customUserGroups.targetedUserGroup

/**********************************************************************
 * Function: GetCustomUserGroupMembers
 *
 * Purpose: Retrieves the members of the specified Custom User Group
 *
 * Input: TARGET_CPC_NAME - The target CPC's name
 *        TARGET_GROUP_URI - The target group URI
 *
 * Output: A stem tail variable where the variable's values correspond
 *         to the following:
 *
 *         customUserGroupMems.0 = N number of custom user group members
 *         customUserGroupMems.<Member_Name1> = <Member_URI1>
 *         customUserGroupMems.<Member_Name2> = <Member_URI2>
 *         ...
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetCustomUserGroupMembers:

  TARGET_CPC_NAME = Arg(1)
  TARGET_GROUP_URI = Arg(2)

  GROUP_MEMBERS_KEY = 'members'
  GROUP_MEMBER_NAME_KEY = 'name'
  GROUP_MEMBER_URI_KEY = 'object-uri'

  GET_GROUP_MEMBERS_URI = TARGET_GROUP_URI || '/members'

  Drop customUserGroupMems.
  customGroupMembersResponse = ''

  customGroupMembersResponse = GetRequest(,
    GET_GROUP_MEMBERS_URI,,
    TARGET_CPC_NAME,
  )

  If customGroupMembersResponse = '' Then Do
    Say 'Failed to find customer user group members'
    Return 0
  End

  Call ParseJSONData customGroupMembersResponse

  /*
   * Attempt to find the list of custom groups available to this user
   */
  groupMembersList = FindJSONValue(,
    0,,
    GROUP_MEMBERS_KEY,,
    HWTJ_ARRAY_TYPE,
  )

  If WasJSONValueFound(groupMembersList) = FALSE Then Do
    Return FatalError(,
      'Failed to retrieve Custom User Groups',
    )
  End

  numOfCustUsrGrpMems = GetJSONArrayDim(groupMembersList)
  If numOfCustUsrGrpMems == 0 Then Do
    Say 'No group members to show for target Custom User Group'

    If removeLPARFromCustomUserGroup == TRUE Then Do
      Return FatalError(,
        'Error: No group members to target for the designated action',
      )
    End
    Else If addLPARToCustomUserGroup == TRUE Then Do
      /*
       * Get out of the function but continue running the script since
       * we want to add a new member to the group
       */
      Return 0
    End
    Else Do
      /*
       * Exit the script since we have no members to display for the
       * target Custom User Group
       */
      Exit 0
    End
  End
  Else If numOfCustUsrGrpMems < 0 Then Do
    Return FatalError(,
      'Unable to retrieve number of group members',
    )
  End

  /********************************************************************
   * Traverse the list of custom user group members to populate the STEM
   * variables. We use the REXX (1-based) idiom  but adjust for the
   * differing (0-based) idiom of the toolkit.
   ********************************************************************/
  Say 'The number of members in the group is: ' || numOfCustUsrGrpMems

  Do memIdx = 1 to numOfCustUsrGrpMems

    /*
     * Grab the next entry within the Custom Groups List
     */
    nextMemberEntry = GetJSONArrayEntry(groupsList, memIdx - 1)

    customUsrGrpMemberName = FindJSONValue(,
      nextMemberEntry,,
      GROUP_MEMBER_NAME_KEY,,
      HWTJ_STRING_TYPE,
    )

    If WasJSONValueFound(customUsrGrpMemberName) = FALSE Then Do
      Say 'Failed to find Custom User Group Member name'
      Return 0
    End

    customUsrGrpMemberURI = FindJSONValue(,
      nextMemberEntry,,
      GROUP_MEMBER_URI_KEY,,
      HWTJ_STRING_TYPE,
    )

    If WasJSONValueFound(customUsrGrpMemberURI) = FALSE Then Do
      Say 'Failed to find Custom User Group Member URI'
      Return 0
    End

    customUserGroupMems.customUsrGrpMemberName = customUsrGrpMemberURI

    Say 'Custom User Group Member Name: ' ||,
        customUsrGrpMemberName ||,
        ' | URI: ' ||,
        customUserGroupMems.customUsrGrpMemberName
  End

  customUserGroupMems.0 = numOfCustUsrGrpMems

Return 0

/**********************************************************************
 * Function: AddNewGroupMember
 *
 * Purpose: Add a new LPAR group member to the specified Custom User
 *          Group
 *
 * Input: GROUP_ID - The ID of the group to target
 *        LPAR_URI - The URI of the lpar object to add to the group
 *        TARGET_CPC_NAME - The name of the CPC to target
 *
 * Output: None
 *
 * Side-Effects:
 *
 *  1. Adds an lpar object to the custom user group
 *
 **********************************************************************/
AddNewGroupMember:

  GROUP_ID = Arg(1)
  LPAR_URI = Arg(2)
  TARGET_CPC_NAME = Arg(3)

  ADD_GROUP_MEMBER_URI = GROUP_ID || '/operations/add-member'

  ADD_GROUP_MEMBER_BODY = '{"object-uri":"' || LPAR_URI || '"}'

  postRequestResponse = PostRequest(,
    ADD_GROUP_MEMBER_URI,,
    ADD_GROUP_MEMBER_BODY,,
    TARGET_CPC_NAME,
  )

Return 0

/**********************************************************************
 * Function: RemoveGroupMember
 *
 * Purpose: Remove a LPAR group member from the specified Custom User
 *          Group
 *
 * Input: GROUP_ID - The ID of the group to target
 *        LPAR_URI - The URI of the lpar object to add to the group
 *        TARGET_CPC_NAME - The name of the CPC to target
 *
 * Output: None
 *
 * Side-Effects:
 *
 *  1. Removes an lpar object from the custom user group
 *
 **********************************************************************/
RemoveGroupMember:

  GROUP_ID = Arg(1)
  LPAR_URI = Arg(2)
  TARGET_CPC_NAME = Arg(3)

  ADD_GROUP_MEMBER_URI = GROUP_ID || '/operations/remove-member'

  ADD_GROUP_MEMBER_BODY = '{"object-uri":"' || LPAR_URI || '"}'

  postRequestResponse = PostRequest(,
    ADD_GROUP_MEMBER_URI,,
    ADD_GROUP_MEMBER_BODY,,
    TARGET_CPC_NAME,,
    '',,
    '',,
    '',
  )

Return 0

/**********************************************************************
 * Function: GetRequest
 *
 * Purpose: Mimic a generic GET request
 *
 * NOTE: Default to a GET of all the cpcs if no args provided
 *
 * Optional Input:
 *   uri         - The URI to target with a GET request
 *   targetName  - The target name of the object to send the request to
 *   requestBody - The JSON request body
 *   client_corr - The client correlator
 *   encoding    - The encoding as an integer
 *   timeout     - The timeout as an integer
 *
 * Output: On success, returns the respones body. On failure, returns
 *         an empty string
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetRequest:

  GET_URI_DEFAULT = '/api/cpcs'
  GET_TARGETNAME_DEFAULT = ''
  GET_REQUESTBODY_DEFAULT = ''
  GET_CLIENTCORR_DEFAULT = ''
  GET_ENCODING_DEFAULT = 0
  /* use default timeout of 60 minutes */
  GET_TIMEOUT_DEFAULT = 0

  uriArg = Arg(1)
  targetnameArg = Arg(2)
  requestBodyArg = Arg(3)
  clientCorrArg = Arg(4)
  encodingArg = Arg(5)
  timeoutArg = Arg(6)

  /*
   * Reset the STEM variables
   */
  Drop userRequest.
  Drop response.

  /*
   * Set the default values for the GET request
   */

  specifiedURI = GET_URI_DEFAULT
  specifiedTargetName = GET_TARGETNAME_DEFAULT
  specifiedRequestBody = GET_REQUESTBODY_DEFAULT
  specifiedClientCorr = GET_CLIENTCORR_DEFAULT
  specifiedEncoding = GET_ENCODING_DEFAULT
  specifiedTimeout = GET_TIMEOUT_DEFAULT

  /*
   * Assign the fields appropriately
   */
  If uriArg <> '' Then
    specifiedURI = uriArg

  If targetnameArg <> '' Then
    specifiedTargetName = targetnameArg

  If requestBodyArg <> '' Then
    specifiedRequestBody = requestBodyArg

  If clientCorrArg <> '' Then
    specifiedClientCorr = clientCorrArg

  If encodingArg <> 0 & encodingArg <> '' Then
    specifiedEncoding = encodingArg

  If timeoutArg <> 0 & timeoutArg <> '' Then
    specifiedTimeout = timeoutArg

  userRequest.HTTPMETHOD = HWI_REST_GET
  userRequest.URI = specifiedURI
  userRequest.TARGETNAME = specifiedTargetName
  userRequest.REQUESTBODY = specifiedRequestBody
  userRequest.CLIENTCORRELATOR = specifiedClientCorr
  userRequest.ENCODING = specifiedEncoding
  userRequest.REQUESTTIMEOUT = specifiedTimeout

  Say
  Say '------->'
  Say 'GET request being made....'
  Say 'URI: ' || userRequest.URI

  If userRequest.TARGETNAME <> '' Then
    Say 'TARGETNAME: '||userRequest.TARGETNAME

  If userRequest.REQUESTBODY <> '' Then
    Say 'REQUEST BODY: '||userRequest.REQUESTBODY

  If userRequest.CLIENTCORRELATOR <> '' Then
    Say 'CLIENT CORRELATOR: '||userRequest.CLIENTCORRELATOR

  If userRequest.ENCODING <> '' Then
    Say 'ENCODING: '||userRequest.ENCODING

  If userRequest.REQUESTTIMEOUT <> '' Then
    Say 'TIMEOUT: '||userRequest.REQUESTTIMEOUT

  Address BCPII "HWIREST userRequest. response."

  /* GET requests return 200 when successful */

  Call SurfaceResponse RC
  Say
  Say '<-------'
  Say

  responseData = ''

  If RC = 0 & response.httpStatus = 200 Then
    responseData = response.responseBody

  Drop userRequest.
  Drop response.

Return responseData

/**********************************************************************
 * Function: PostRequest
 *
 * Purpose: Invoke HWIREST, http method == POST, for the input uri and
 *          related args.
 *
 * Input:
 *  Required:
 *    argUri - The URI string to issue the POST request to
 *    argRequestBody - The request body to send with the POST request
 *    argTarget - The target name for the POST request
 *
 *  Optional:
 *    argEncoding - The encoding type for the POST request
 *    argTimeout - The timeout for the POST request
 *    argClientCorr - The client correlator for the POST request
 *    ignoreRequestErr - A flag to ignore a failed POST request
 *
 * Output: The response body of the request as a string
 *
 * Side-Effects: None
 *
 **********************************************************************/
PostRequest:

  /*
   * Initialize symbols
   */
  specifiedURI = ''
  specifiedTargetName = ''
  specifiedRequestBody = ''
  specifiedClientCorr = ''
  specifiedEncoding = 0
  specifiedTimeout = 0
  ignoreRequestErr = FALSE

  /*
   * Required arguments
   */
  uriArg = Arg(1)
  requestBodyArg = Arg(2)
  targetnameArg = Arg(3)

  /*
   * Optional arguments
   */
  encodingArg = Arg(4)
  timeoutArg = Arg(5)
  clientCorrArg = Arg(6)
  ignoreRequestErrArg = Arg(7)

  If (,
    uriArg == '' |,
    requestBodyArg == '' |,
    targetnameArg == '',
  ) Then Do
    errMsg = 'Missing one of the following required arguments for ' ||,
             'a POST request: URI, TargetName, or RequestBody'
    Exit FatalErrorAndCleanup(errMsg)
  End

  specifiedURI = uriArg
  specifiedTargetName = targetnameArg
  specifiedRequestBody = requestBodyArg

  If clientCorrArg <> '' Then
    specifiedClientCorr = clientCorrArg

  If encodingArg <> 0 & encodingArg <> '' Then
    specifiedEncoding = encodingArg

  If timeoutArg <> 0 & timeoutArg <> '' Then
    specifiedTimeout = timeoutArg

  If ignoreRequestErrArg <> '' & ignoreRequestErrArg == TRUE Then
    ignoreRequestErr = TRUE

  Drop userRequest.
  Drop response.

  userRequest.HTTPMETHOD = HWI_REST_POST
  userRequest.URI = specifiedURI
  userRequest.TARGETNAME = specifiedTargetName
  userRequest.REQUESTTIMEOUT = specifiedTimeout
  userRequest.REQUESTBODY = specifiedRequestBody
  userRequest.CLIENTCORRELATOR = specifiedClientCorr
  userRequest.ENCODING = specifiedEncoding

  Say
  Say '------->'
  Say 'POST request being made....'
  Say 'URI: ' || userRequest.URI
  Say 'TARGETNAME: '|| userRequest.TARGETNAME
  Say 'REQUEST BODY: '|| userRequest.REQUESTBODY
  Say 'CLIENT CORRELATOR: '|| userRequest.CLIENTCORRELATOR
  Say 'ENCODING: '|| userRequest.ENCODING
  Say 'TIMEOUT: '|| userRequest.REQUESTTIMEOUT

  Address BCPII "HWIREST userRequest. response."

  Call SurfaceResponse RexxRC

  If response.httpStatus < 200 | response.httpStatus > 299 Then Do
    If ignoreRequestErr == TRUE & response.httpStatus == 400 Then Do
      RexxRC = 0
      RC = 0
    End
    Else Do
      Exit FatalErrorAndCleanup(,
        'Failed making POST request',
      )
    End
  End

  responseData = ''
  If response.responseBody <> '' Then
    responseData = response.responseBody

  Drop userRequest.
  Drop response.

Return responseData

/**********************************************************************
 *              JSON ToolKit Helper Functions
 **********************************************************************/

/**********************************************************************
 * Function:  GetJSONToolkitConstants
 *
 * Purpose: Access constants used by the toolkit (for return codes,
 *          etc), via the HWTCONST toolkit API.
 *
 * Input: None
 *
 * Output: A boolean indicating
 *
 * Returns: 0 if toolkit constants accessed, -1 if not
 **********************************************************************/
GetJSONToolkitConstants:
  If VERBOSE Then
    Say 'Setting hwtcalls on'

  /********************************************************************
   * Ensure that the toolkit host command is available in your REXX
   * environment (no harm done if already present). Do this before
   * your first toolkit API invocation.
   ********************************************************************/
  Call hwtcalls "on"
  If VERBOSE Then
    Say 'Including HWT Constants...'

  /********************************************************************
   * Call the HWTCONST toolkit API.  This should make all
   * toolkit-related constants available to procedures via (expose of)
   * HWT_CONSTANTS
   ********************************************************************/
  ReturnCode = -1
  DiagArea. = ''
  Address hwtjson "hwtconst ",
                  "ReturnCode ",
                  "DiagArea."
  RexxRC = RC
  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Call SurfaceJSONDiag 'hwtconst', RexxRC, ReturnCode, DiagArea.
    Return FatalError( 'HWTCONST (json) failure' )
  End

Return 0

/***********************************************************************
 * Function: InitJSONParser
 *
 * Purpose: Create a Json parser instance via the HWTJINIT toolkit API.
 *          Initializes the global variable parserHandle with the
 *          handle returned by the API. This handle is required by
 *          other toolkit API's (and so this HWTJINIT API must be
 *          invoked before invoking any other parse-related API).
 *
 * Input: None
 *
 * Output: Returns a boolean indicating whether the initialization was
 *         sucessful (0 if successful, -1 if not.)
 *
 * Side-Effects:
 *
 *  1. Initializes a JSON Parser for JSON processing
 *
 **********************************************************************/
InitJSONParser:
  If VERBOSE Then
    Say 'Initializing Json Parser'

  /*********************************************************************
   * Call the HWTJINIT toolkit API.
   ********************************************************************/
  ReturnCode = -1
  DiagArea. = ''
  Address hwtjson "hwtjinit ",
                  "ReturnCode ",
                  "handleOut ",
                  "DiagArea."
  RexxRC = RC
  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Call SurfaceJSONDiag 'hwtjinit', RexxRC, ReturnCode, DiagArea.
    Return FatalError('HWTJINIT failure')
  End

  /*********************************************************************
   * By default the parser handle declared in the Main() is seen as a
   * global variable and therefore we can reference it here
   ********************************************************************/
  parserHandle = handleOut
  If VERBOSE Then
    Say 'Json Parser init (HWTJINIT) succeeded'

 PARSER_INIT = TRUE
Return 0

/***********************************************************************
 * Function: ReInitParser
 *
 * Purpose: Terminate the existing parser handle and initialize a
 *          brand new parser handle.
 *
 * Input: None
 *
 * Output: Returns a boolean indicating whether the reinitialization
 *         was successful or not (0 if successful)
 *
 * Side-Effects:
 *
 *  1. If ther parser was initialized, then we terminate the JSON
 *     parser
 *  2. Initializes the JSON parser
 *  3. Exits the program with a fatal error and cleanups if an error
 *     occured during reinitialization
 *
 **********************************************************************/
ReInitParser:
  If PARSER_INIT Then Do
    /* set ahead of time because we want to avoid an endless error
     * loop in the event TermJSONParser invokes FatalError and
     * goes through this path again
     */
    PARSER_INIT = FALSE
    Call TermJSONParser
  End

  Call InitJSONParser
  If RESULT <> 0 Then
    Exit FatalErrorAndCleanup( 'JSON parser init failure' )

Return 0

/***********************************************************************
 * Function: WasJSONValueFound
 *
 * Purpose: Return FALSE if the content is an empty string or the string
 *          '(not found)', otherwise return TRUE
 *
 * Input: valueString - The string to analyze
 *
 * Output: A boolean indicating whether a value was found
 *
 * Side-Effects: None
 *
 **********************************************************************/
WasJSONValueFound:
  valueString = Arg(1)

  foundValue = TRUE

  If valueString = '' | valueString = '(not found)' Then
    foundValue = FALSE

Return foundValue

/**********************************************************************
 * Function:  WasJSONNotFound
 *
 * Purpose: Check the input processing codes.
 *
 * NOTE: That if the input RexxRC is nonzero, then the toolkit return
 *       code is moot (the toolkit function was likely not even
 *       invoked). If the toolkit return code is relevant, check it
 *       against the specific return code for a "not found" condition.
 *
 * Input: RexxRC - The Rexx return code to analyze
 *
 * Output: A boolen indicating whether the JSON was not found or not
 *         (1 if HWTJ_JSRCH_SRCHSTR_NOT_FOUND condition, 0 otherwise.
 *
 * Side-Effects: None
 *
 **********************************************************************/
WasJSONNotFound:
  RexxRC = Arg(1)
  ToolkitRC = strip(Arg(2),'L',0)

  If RexxRC <> 0 | ToolkitRC <> HWTJ_JSRCH_SRCHSTR_NOT_FOUND Then
    Return 0

Return 1

/***********************************************************************
 * Function:  IsThereAJSONError
 *
 * Purpose: Check the input processing codes. Note that if the input
 *          RexxRC is nonzero, then the toolkit return code is moot
 *          (the toolkit function was likely not even invoked). If
 *          the toolkit return code is relevant, check it against the
 *          set of { HWTJ_xx } return codes for evidence of error.
 *          This set is ordered: HWTJ_OK < HWTJ_WARNING < ...
 *          with remaining codes indicating error, so we may check
 *          via single inequality.
 *
 * Input: RexxRC - The current return code of our REXX script
 *        ToolkitRC - The current return code of the Toolkit
 *
 * Output: A boolean indicating if there is a JSON error ( 0 for
 *         successful and 1 for a failure)
 *
 * Side-Effects: None
 *
 **********************************************************************/
IsThereAJSONError:
  RexxRC = Arg(1)
  If RexxRC <> 0 Then
    Return 1
  ToolkitRC = strip(Arg(2),'L',0)
  If ToolkitRC == '' Then
    Return 0
  If ToolkitRC <= HWTJ_WARNING Then
    Return 0
Return 1

/**********************************************************************
 * NOTE: the following was taken from sample hwtjxrx1.rexx
 **********************************************************************/
/**********************************************************************
 * Function: TraverseJsonObject
 *
 * Purpose: Traverses the designated object. Traversal is accomplished
 *          by retrieving each object entry, and invoking
 *          TraverseJsonEntry upon it.
 *
 * NOTE: That the nature of a given entry may result in a recursive
 *       call to this procedure.
 *
 * Output: A boolean indicating whether the traversal succeeded
 *         (0 if successful, -1 if not.)
 *
 * Side-Effects:
 *
 *  1. Prints the JSON entries
 *
 **********************************************************************/
TraverseJsonObject: Procedure Expose (PROC_GLOBALS)
  objectHandle = Arg(1)
  indentLevel = Arg(2)

  /********************************************************************
   * First, determine the number of name:value pairs in the object.
   ********************************************************************/
  numEntries = GetNumOfJSONObjectEntries(objectHandle)

  If numEntries <= 0 Then
    Return FatalError('Unable to determine num object entries')

  /********************************************************************
   * Since the REXX iteration idiom is 1-based, we iterate from 1
   * until the object is exhausted or fatal error.  However the
   * Parser has a different (0-based) idiom, so we adjust the
   * index value accordingly when we use it.
   ********************************************************************/
  Do i = 1 To numEntries
      /****************************************************************
       * Retrieve the next name:value pair into the objectEntry. stem
       * variable
       ****************************************************************/
      objectEntry. = ''

      Call GetJSONObjectEntry objectHandle, i-1

      If RESULT <> 0 Then
        Return FatalError(,
          'Unable to obtain object entry (' || i-1 ||')',
        )

      /****************************************************************
       * Print the entry name (portion of the name:value pair)
       ****************************************************************/
      Say Indent(objectEntry.name,indentLevel)

      /****************************************************************
       * Print the value portion of this entry. This may or may not be
       * a simple value, so we call a value traversal function to
       * handle all cases
       ****************************************************************/
      Call TraverseJsonEntry objectEntry.valueHandle, 2+indentLevel

  End
Return 0

/**********************************************************************
 * Function: TraverseJsonEntry
 *
 * Purpose: Perform a depth-first traversal of the designated JSON
 *          entry, to demonstrate a common means of "auto-discovering"
 *          JSON data.
 *
 *          Recursion occurs when the input handle designates an array
 *          or object type. When the input handle designates a primitive
 *          type (e.g, string, number, boolean, or null type), the value
 *          is retrieved and displayed.
 *
 * NOTE: This type of "auto-discovery" is especially useful when the
 *       data is unpredictable (not guaranteed to contain particular
 *       name:value pairs).
 *
 * Input: entryHandle - The JSON parser handle to utilize for parsing a
 *                      JSON
 *        indentLevel - The whitespace indent level to utilize when
 *                      printing the JSON object
 *
 * Output: A boolean indicating whether the traversal was successful
 *         (0 if successful, -1 if not.)
 *
 * Side-Effects: None
 *
 **********************************************************************/
TraverseJsonEntry: Procedure Expose (PROC_GLOBALS)

  entryHandle = Arg(1)
  indentLevel = Arg(2)

  /********************************************************************
   * To properly traverse the entry, we first must determine its type
   ********************************************************************/
  entryType = GetJSONType(entryHandle)

  Select
    When entryType == HWTJ_OBJECT_TYPE Then Do
      Call TraverseJsonObject entryHandle, 2+indentLevel
    End
    When entryType == HWTJ_ARRAY_TYPE Then Do
      Call TraverseJsonArray entryHandle, 2+indentLevel
    End
    When entryType == HWTJ_STRING_TYPE Then Do
      value = GetJSONValue(entryHandle, HWTJ_STRING_TYPE)
      Say Indent(value,indentLevel)
    End
    When entryType == HWTJ_NUMBER_TYPE Then Do
      value = GetJSONValue(entryHandle, HWTJ_NUMBER_TYPE)
      Say Indent(value,indentLevel)
    End
    When entryType == HWTJ_BOOLEAN_TYPE Then Do
      value = GetJSONValue(entryHandle, HWTJ_BOOLEAN_TYPE)
      Say Indent(value,indentLevel)
    End
    when entryType == HWTJ_NULL_TYPE Then Do
      value = '(null)'
      Say Indent(value,indentLevel)
    End
    Otherwise Do
      /****************************************************************
       * If we've reached this point there is a problem.
       ****************************************************************/
      Return FatalError( 'Unable to retrieve JSON type' )
    End
  End

Return 0

/**********************************************************************
 * Function: TraverseJsonArray
 *
 * Purpose: Traverses the designated array. Traversal is accomplished by
 *          retrieving each entry, and invoking TraverseJsonEntry upon
 *          it.
 * NOTE: That the nature of a given entry may result in a recursive call
 *       to this procedure.
 *
 * Input: arrayHandle - The array handle to use for parsing the array
 *        indentLevel - The level of whitespace indentation for printing
 *
 * Output: A boolean indicating whether the JSON array traversal was
 *         was successful (0 if successful, -1 if not.)
 *
 * Side-Effects: None
 *
 **********************************************************************/
TraverseJsonArray: Procedure Expose (PROC_GLOBALS)
  arrayHandle = Arg(1)
  indentLevel = Arg(2)

  numEntries = GetJSONArrayDim( arrayHandle )
  If numEntries == 0 Then Do
    Say 'Traversed an empty array'
    Return 0
  End

  /********************************************************************
   * Loop, getting each array entry, and traversing it.
   * Again, we must reconcile the the REXX 1-based idiom
   * with that of the  toolkit.
   ********************************************************************/
  Do i = 1 To numEntries
    entryHandle = GetJSONArrayEntry( arrayHandle, i-1 )
    Call TraverseJsonEntry entryHandle, 2+indentLevel
  End
Return 0

/**********************************************************************
 * Function: GetJSONValue
 *
 * Purpose: Return the value portion of the designated Json object
 *          according to its type.  If this type indicates a simple data
 *          value, then one of the "get value" toolkit APIs (HWTJGVAL,
 *          HWTJGBOV) is used. If the type an object or array, then the
 *          handle is simply echoed back.
 *
 * Input: entryHandle - The JSON entry handle to utilize for retrieving
 *                      the value
 *        valueType   - The type of value to attempt to retrieve
 *
 * Output: The value of the designated entry as described
 *         above, if successful. An empty string is returned otherwise.
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetJSONValue:

  entryHandle = arg(1)
  valueType = arg(2)

  /*
   * Get the value for a String or Number type
   */
  If (,
      valueType == HWTJ_STRING_TYPE |,
      valueType == HWTJ_NUMBER_TYPE,
  ) Then Do
    /*
     * Call the HWTJGVAL toolkit API.
     */
    ReturnCode = -1
    DiagArea. = ''
    Address HWTJSON "hwtjgval ",
                    "ReturnCode ",
                    "parserHandle ",
                    "entryHandle ",
                    "valueOut ",
                    "DiagArea."
    RexxRC = RC

    If IsThereAJSONError(RexxRC,ReturnCode) Then Do
      Call SurfaceJSONDiag 'hwtjgval', RexxRC, ReturnCode, DiagArea.
      Say 'HWTJGVAL failure'
      valueOut = ''
    End

    Return valueOut
  End

  /*
   * Get the value for a Boolean type
   */
  If valueType == HWTJ_BOOLEAN_TYPE Then Do

    ReturnCode = -1
    DiagArea. = ''

    /*
     * Call the HWTJGBOV toolkit API
     */
    Address HWTJSON "hwtjgbov ",
                    "ReturnCode ",
                    "parserHandle ",
                    "entryHandle ",
                    "valueOut ",
                    "DiagArea."
    RexxRC = RC
    If IsThereAJSONError(RexxRC,ReturnCode) Then Do
      Call SurfaceJSONDiag 'hwtjgbov', RexxRC, ReturnCode, DiagArea.
      Say 'HWTJGBOV failure'
      valueOut = ''
    End

    Return valueOut
  End

  /*
   * Use at your own discretion for NULL type
   */
  If valueType == HWTJ_NULL_TYPE Then Do
    valueOut = '*null*'
    Say 'Returning arbitrary ' || valueOut || ' for null type'
    Return valueOut
  End

  /********************************************************************
   * To reach this point, valueType must be a non-primitive type
   * (i.e., either HWTJ_ARRAY_TYPE or HWTJ_OBJECT_TYPE), and we
   * Simply echo back the input handle as our return value
   ********************************************************************/
Return entryHandle

/**********************************************************************
 * Function:  ParseJSONData
 *
 *  Purpose: Parse the input text body via call to the HWTJPARS toolkit
 *           API. HWTJPARS builds an internal representation of the
 *           input JSON text which allows search, traversal, and
 *           modification operations against that representation.
 *
 *  NOTE: That HWTJPARS does *not* make its own copy of the input
 *        source, and therefore the caller must ensure that the
 *        provided source string remains unmodified for the duration
 *        of the associated parser instance (i.e., if the source
 *        string is modified, subsequent service call behavior and
 *        results from the parser are unpredictable).
 *
 * Input: jsonTextBody - The JSON text body to parse
 *
 * Output: A boolean indicating whether the parsing of the JSON data
 *          was successful or not (0 if successful, -1 if not).
 *
 * Side-Effects: None
 *
 **********************************************************************/
ParseJSONData:

  Call ReInitParser

  jsonTextBody = Arg(1)

  If VERBOSE Then
    Say 'Invoke Json Parser'
  /*
   * Call the HWTJPARS toolkit API.
   */
  ReturnCode = -1
  DiagArea. = ''

  Address HWTJSON "hwtjpars ",
                  "ReturnCode ",
                  "parserHandle ",
                  "jsonTextBody ",
                  "DiagArea."
  RexxRC = RC

  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Call SurfaceJSONDiag 'hwtjpars', RexxRC, ReturnCode, DiagArea.
    Return FatalError( 'HWTJPARS failure' )
  End

  If VERBOSE Then
    Say 'JSON data parsed successfully'
Return 0

/**********************************************************************
 * Function:  TermJSONParser
 *
 * Purpose: Cleans up parser resources and invalidates the parser
 *          instance handle, via call to the HWTJTERM toolkit API.
 *
 * NOTE: That as the REXX environment is single-threaded, no
 *       no consideration of any "busy" outcome from the API is
 *       done (as it would be in other language environments).
 *
 * Input: None
 *
 * Output: A boolean indicating whether the termination of the JSON
 *         parser was successful (0 if successful, -1 if not.)
 *
 * Side-Effects:
 *
 *  1. Terminates the JSON parser as designated by the parserHandle
 *     variable
 *
 **********************************************************************/
TermJSONParser:
  If VERBOSE Then
    Say 'Terminate Json Parser'

  /*
   * Call the HWTJTERM toolkit API.
   */
  ReturnCode = -1
  DiagArea. = ''

  Address HWTJSON "hwtjterm ",
                  "ReturnCode ",
                  "parserHandle ",
                  "DiagArea."
  RexxRC = RC

  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Call SurfaceJSONDiag 'hwtjterm', RexxRC, ReturnCode, DiagArea.
    Return FatalError('HWTJTERM failure')
  End

  If VERBOSE Then
    Say 'Json Parser terminated'

Return 0

/**********************************************************************
 * Function: JSONToString
 *
 * Purpose: Creates a single string representation of the Json parser's
 *          current data, via call to the HWTJSERI toolkit API. This is
 *          typically used after having used create services to modify
 *          or insert additional JSON data. If an an error occurs
 *          during serialization, an empty string is produced.
 *
 * Input: None
 *
 * Output: A string as described above.
 *
 * Side-Effects: None
 *
 **********************************************************************/
JSONToString:
  If VERBOSE Then
    Say 'Serialize Parser data'

  /*
   * Call the HWTJSERI toolkit API.
   */
  ReturnCode = -1
  DiagArea. = ''

  Address HWTJSON "hwtjseri ",
                  "ReturnCode ",
                  "parserHandle ",
                  "serializedDataOut ",
                  "DiagArea."
  RexxRC = RC

  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Call SurfaceJSONDiag 'hwtjseri', RexxRC, ReturnCode, DiagArea.
    Say 'Unable to serialize JSON data'
    Return ''
  End

  If VERBOSE Then
    Say 'JSON data serialized'

Return serializedDataOut

/**********************************************************************
 * Function:  FindJSONValue
 *
 * Purpose: Return the value associated with the input name from
 *          the designated JSON object, via the various toolkit
 *          API's { HWTJSRCH, HWTJGVAL, HWTJGBOV }, as appropriate.
 *
 * Input: objectToSearch - The object to search for the value of
 *                         interest
 *        searchName     - The name of the value to search for
 *        expectedType   - The expected type of the value
 *
 * Output: The value of the designated entry in the designated JSON
 *         object, if found and of the designated type, or suitable
 *         failure string if not.
 *
 * Side-Effects: None
 *
 **********************************************************************/
FindJSONValue:

  objectToSearch = Arg(1)
  searchName = Arg(2)
  expectedType = Arg(3)

  /*
   * Search the specified object for the specified name
   */
  If VERBOSE Then
    Say 'Invoke Json Search for 'searchName

  /********************************************************************
   * Invoke the HWTJSRCH toolkit API.
   * The value 0 is specified (for the "startingHandle")
   * to indicate that the search should start at the
   * beginning of the designated object.
  *********************************************************************/
  ReturnCode = -1
  DiagArea. = ''

  Address HWTJSON "hwtjsrch ",
                  "ReturnCode ",
                  "parserHandle ",
                  "HWTJ_SEARCHTYPE_OBJECT ",
                  "searchName ",
                  "objectToSearch ",
                  "0 ",
                  "searchResult ",
                  "DiagArea."
  RexxRC = RC

  /********************************************************************
   * Differentiate a not found condition from an error, and
   * tolerate the former.  Note the order dependency here,
   * at least as the called routines are currently written.
   ********************************************************************/
  If WasJSONNotFound(RexxRC,ReturnCode) Then
    Return '(not found)'

  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Call SurfaceJSONDiag 'hwtjsrch', RexxRC, ReturnCode, DiagArea.
    Say 'HWTJSRCH failure'
    Return ''
  End

  /********************************************************************
   * Process the search result, according to type.  We should first
   * verify the type of the search result.
   ********************************************************************/
  resultType = GetJSONType( searchResult )

  If resultType <> expectedType Then Do
    If VERBOSE Then
      Say 'Type mismatch (' ||,
          resultType || ','    ||,
          expectedType || ')'

    If resultType == HWTJ_FALSEVALUETYPE Then
      Return 'false'
    Else If resultType == HWTJ_TRUEVALUETYPE Then
      Return 'true'
    Else If resultType == HWTJ_NULLVALUETYPE Then
      Return 'null'

    Return ''

  End

  /********************************************************************
   * If the expected type is not a simple value, then the search result
   * is itself a handle to a nested object or array, and we simply
   * return it as such.
  *********************************************************************/
  If (,
    expectedType == HWTJ_OBJECT_TYPE |,
    expectedType == HWTJ_ARRAY_TYPE,
  ) Then Do

    Return searchResult

  End

  /*
   * Return the located string or number, as appropriate
   */
  If (,
    expectedType == HWTJ_STRING_TYPE |,
    expectedType == HWTJ_NUMBER_TYPE,
  ) Then Do

    If VERBOSE Then
      Say 'Invoke Json Get Value'

    /*
     * Call the HWTJGVAL toolkit API
     */
    ReturnCode = -1
    DiagArea. = ''
    Address HWTJSON "hwtjgval ",
                    "ReturnCode ",
                    "parserHandle ",
                    "searchResult ",
                    "result ",
                    "DiagArea."
    RexxRC = RC

    If IsThereAJSONError(RexxRC,ReturnCode) Then Do
      Call SurfaceJSONDiag 'hwtjgval', RexxRC, ReturnCode, DiagArea.
      Say 'HWTJGVAL failure'
      Return ''
    End

    Return result

  End

  /*
   * Return the located boolean value, as appropriate
   */
  If expectedType == HWTJ_BOOLEAN_TYPE then Do
    If VERBOSE Then
      Say 'Invoke Json Get Boolean Value'

    /*
      * Call the HWTJGBOV toolkit API
      */
    ReturnCode = -1
    DiagArea. = ''
    Address HWTJSON "hwtjgbov ",
                    "ReturnCode ",
                    "parserHandle ",
                    "searchResult ",
                    "result ",
                    "DiagArea."
    RexxRC = RC

    If IsThereAJSONError(RexxRC,ReturnCode) Then Do
      Call SurfaceJSONDiag 'hwtjgbov', RexxRC, ReturnCode, DiagArea.
      Say 'HWTJGBOV failure'
      Return ''
    End

    Return result

  End

  /********************************************************************
   * This return should not occur, in practice
   *
   * NOTE: That we did not account for expected type == HWTJ_NULL_TYPE
   *       and could do so here if that were meaningful (but more
   *       efficiently we might do that earlier in the routine to
   *       avoid wasteful processing).
   ********************************************************************/
  If VERBOSE Then
    Say 'No return value found'

Return ''

/**********************************************************************
 * Function:  GetJSONType
 *
 * Purpose: Determine the JSON type of the designated search result
 *          via the HWTJGJST toolkit API
 *
 * Input: searchResult - The variable whose type needs to be determined
 *
 * Output: Non-negative integral number indicating type
 *         (if successful, -1 if not).
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetJSONType:
  searchResult = Arg(1)

  If VERBOSE Then
    Say 'Invoke Json Get Type'

  /*
   * Call the HWTJGJST toolkit API.
   */
  ReturnCode = -1
  DiagArea. = ''
  Address HWTJSON "hwtjgjst ",
                  "ReturnCode ",
                  "parserHandle ",
                  "searchResult ",
                  "resultTypeName ",
                  "DiagArea."
  RexxRC = RC

  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Call SurfaceJSONDiag 'hwtjgjst', RexxRC, ReturnCode, DiagArea.
    Return FatalError( 'HWTJGJST failure' )
  End
  Else Do
    /******************************************************************
     * Convert the returned type name into its equivalent constant, and
     * return that more convenient value.
     *
     * NOTE: That the interpret instruction might more typically be used
     *       here, but the goal here is to familiarize the reader with
     *       these types.
     ******************************************************************/
    type = Strip(resultTypeName)

    If type == 'HWTJ_STRING_TYPE' Then
      Return HWTJ_STRING_TYPE
    If type == 'HWTJ_NUMBER_TYPE' Then
      Return HWTJ_NUMBER_TYPE
    If type == 'HWTJ_BOOLEAN_TYPE' Then
      Return HWTJ_BOOLEAN_TYPE
    If type == 'HWTJ_ARRAY_TYPE' Then
      Return HWTJ_ARRAY_TYPE
    If type == 'HWTJ_OBJECT_TYPE' Then
      Return HWTJ_OBJECT_TYPE
    If type == 'HWTJ_NULL_TYPE' Then
      Return HWTJ_NULL_TYPE
  End

  /*
   * This return should not occur, in practice.
   */
Return FatalError('Unsupported Type (' || type || ') from hwtjgjst')

/**********************************************************************
 * Function:  GetJSONArrayDim
 *
 * Purpose: Return the number of entries in the array designated by the
 *          input handle, obtained via the HWTJGNUE toolkit API.
 *
 * Input: arrayHandle - The arrayHandle to process and size
 *
 * Output: Non-negative integral number of array entries if successful,
 *         -1 if not.
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetJSONArrayDim:

  arrayHandle = Arg(1)

  If VERBOSE Then
    Say 'Getting array dimension'

  /*
   * Call the HWTJGNUE toolkit API
   */
  ReturnCode = -1
  DiagArea. = ''
  Address HWTJSON "hwtjgnue ",
                  "ReturnCode ",
                  "parserHandle ",
                  "arrayHandle ",
                  "dimOut ",
                  "DiagArea."
  RexxRC = RC

  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Call SurfaceJSONDiag 'hwtjgnue', RexxRC, ReturnCode, DiagArea.
    Return FatalError( 'HWTJGNUE failure' )
  End

  arrayDim = strip(dimOut,'L',0)

  If arrayDim == '' Then
    Return 0

Return arrayDim

/**********************************************************************
 * Function:  GetJSONArrayEntry
 *
 * Purpose: Return a handle to the designated entry of the array
 *          designated by the input handle, obtained via the HWTJGAEN
 *          toolkit API.
 *
 * Input: arrayHandle - The array handle to utilize when attempting to
 *                      retrieve an array entry
 *        whichEntry  - The entry of the array to fetch
 *
 * Output: Output handle from toolkit API if successful, empty result
 *         if not.
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetJSONArrayEntry:
  arrayHandle = Arg(1)
  whichEntry = Arg(2)
  result = ''

  If VERBOSE Then
    Say 'Getting array entry'

  /*
   * Call the HWTJGAEN toolkit API
   */
  ReturnCode = -1
  DiagArea. = ''
  Address HWTJSON "hwtjgaen ",
                  "ReturnCode ",
                  "parserHandle ",
                  "arrayHandle ",
                  "whichEntry ",
                  "handleOut ",
                  "DiagArea."
  RexxRC = RC

  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Call SurfaceJSONDiag 'hwtjgaen', RexxRC, ReturnCode, DiagArea.
    Say 'HWTJGAEN failure'
  End
  Else
    result = handleOut

Return result

/**********************************************************************
 * Function: GetJSONObjectEntry
 *
 * Purpose: Access the designated entry of the designated JSON object
 *          via the HWTJGOEN toolkit API. Populate the caller's
 *          objectEntry. stem variable with the name portion of the
 *          entry, and the valueHandleOut returned by the API
 *          (the value designated by this handle may be any of several
 *          types, and the caller has prior knowledge of, or will,
 *          discover its type so that it can make appropriate use of
 *          it).
 *
 * Input: objectHandle - The JSON object handle
 *        whichEntry   - The entry to retrieve
 *
 * Output: 0 to indicate that the objectEntry. stem variable was
 *         successfully populated, -1 otherwise.
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetJSONObjectEntry:

  objectHandle = Arg(1)
  whichEntry = Arg(2)

  If VERBOSE Then
    Say 'Get object entry (' || whichEntry || ')'

  /*
   * Invoke the HWTJGOEN API to access the designated entry
   */
  ReturnCode = -1
  DiagArea. = ''
  Address HWTJSON "hwtjgoen ",
                  "ReturnCode ",
                  "parserHandle ",
                  "objectHandle ",
                  "whichEntry ",
                  "nameOut ",
                  "valueHandleOut ",
                  "DiagArea."
  RexxRC = RC

  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Say 'Unable to get object entry(' || whichEntry || ')'
    Call SurfaceJSONDiag 'hwtjgoen', RexxRC, ReturnCode, DiagArea.
    Return FatalError( 'HWTJGOEN failure' )
  End

  objectEntry.name = nameOut
  objectEntry.valueHandle = valueHandleOut

Return 0

/**********************************************************************
 * Function: GetNumOfJSONObjectEntries
 *
 * Purpose: Get the number of entries for the JSON object which is
 *          designated by the input handle, via the HWTJGNUE toolkit
 *          API.
 *
 * Input: objectHandle - The object handle to utilize for determining
 *                       the number of object entries in the JSON
 *
 * Output: Non-negative integral number of object entries if successful,
 *         -1 if not.
 *
 * Side-Effects: None
 *
 **********************************************************************/
GetNumOfJSONObjectEntries:
  objectHandle = Arg(1)

  If VERBOSE Then
    Say 'Determining number of object entries'

  /*
   * Call the HWTJGNUE toolkit API
   */
  ReturnCode = -1
  DiagArea. = ''
  Address HWTJSON "hwtjgnue ",
                  "ReturnCode ",
                  "parserHandle ",
                  "objectHandle ",
                  "numEntriesOut ",
                  "DiagArea."
  RexxRC = RC

  If IsThereAJSONError(RexxRC,ReturnCode) Then Do
    Say 'Unable to determine number of object entries'
    Call SurfaceJSONDiag 'hwtjgnue', RexxRC, ReturnCode, DiagArea.
    Return FatalError( 'HWTJGNUE failure' )
  End

  If VERBOSE Then
    Say numEntriesOut || ' entries were found'

Return numEntriesOut

/**********************************************************************
 * Function: SurfaceJSONDiag
 *
 * Purpose: Surface input error information.
 *
 * NOTE: That when the RexxRC is nonzero, the ToolkitRC and DiagArea
 *       content are moot and are suppressed (so as to not mislead).
 *
 * Input: who       - Who is surfacing the JSON error
 *        RexxRC    - The Rexx return code
 *        ToolkitRC - The toolkit return code
 *
 * Output: None
 *
 * Side-Effects:
 *
 *  1. Displays the DiagArea and error information for the Toolkit
 *
**********************************************************************/
SurfaceJSONDiag: Procedure Expose DiagArea.
  who = Arg(1)
  RexxRC = Arg(2)
  ToolkitRC = Arg(3)

  Say
  Say 'Error: (' || who || ') at time: ' || Time()
  Say 'Rexx RC: ' || RexxRC || ', Toolkit ReturnCode: ' || ToolkitRC

  If RexxRC == 0 Then Do
    Say 'DiagArea.ReasonCode: ' || DiagArea.HWTJ_ReasonCode
    Say 'DiagArea.ReasonDesc: ' || DiagArea.HWTJ_ReasonDesc
  End

  Say

Return

/**********************************************************************
 *              Misc. Helper Functions
 **********************************************************************/

/**********************************************************************
 * Function: Indent
 *
 * Purpose: Returns the input string prepended with the designated
 *          number of blanks.
 *
 * Input: target - The input string to indent n number of spaces
 *        indentSize - The number of indents to insert the target over
 *                     by
 *
 * Output: The target string indented n number of times over
 *
 * Side-Effects: None
 *
 **********************************************************************/
Indent:
  source = ''
  target = Arg(1)
  indentSize = Arg(2)
  padChar = ' '
Return Insert(source,target,0,indentSize,padChar)

/**********************************************************************
 * Function: FatalError
 *
 * Purpose: Surfaces the input message, and returns a canonical failure
 *          code.
 *
 * Input: errorMsg - The error msg which will be displayed
 *
 * Output: -1 to indicate fatal script error.
 *
 * Side-Effects:
 *
 *  1. Displays the specified error message
 *
 **********************************************************************/
FatalError:
 errorMsg = Arg(1)
 Say "" || errorMsg
Return -1

/**********************************************************************
 * Function:  FatalErrorAndCleanup
 *
 * Purpose: Surfaces the input message, and invokes cleanup to ensure
 *          the parser is terminated and HWIHOST is set to off, and
 *          returns a canonical failure code.
 *
 * Input: None
 *
 * Output: Returnes a -1 to indicate a fatal script error
 *
 * Side-Effects:
 *
 *  1. Displays the error message to the user
 *
 **********************************************************************/
FatalErrorAndCleanup:
  errorMsg = Arg(1)
  FatalError(errMsg)
  Call Cleanup
Return -1

/**********************************************************************
 * Function: Cleanup
 *
 * Purpose: Terminate the parser instance and, if running in an
 *          ISV REXX environment, turn off HWIHOST.
 *
 * Input: None
 *
 * Output: Returns a boolean indicating sucess (0 is sucessful)
 *
 * Side-Effects:
 *
 *  1. Terminates the initialized JSON Parser
 *  2. Turns off HWIHOST if running in a ISV REXX environment
 *
 **********************************************************************/
Cleanup:

  If PARSER_INIT Then Do
    /* Set ahead of time because we want to avoid an endless error
     * loop in the event TermJSONParser invokes FatalError and
     * goes through this path again
     */
    PARSER_INIT = FALSE
    Call TermJSONParser
  End

  If HWIHOST_ON Then Do
    /*
     * set ahead of time because we want to avoid an endless error
     * loop in the event HWIHOST(OFF) fails and invokes FatalError,
     * which will goes through this path again
     */
    HWIHOST_ON = FALSE
    hwiHostRC = hwihost("OFF")
    Say 'HWIHOST("OFF") return code is: ('||hwiHostRC||')'

    If hwiHostRC <> 0 Then
      Exit FatalErrorAndCleanup('Unable to turn off HWIHOST')
  End

Return 0

/**********************************************************************
 * Function: SurfaceResponse
 *
 * Purpose: Parses through the response parm and if the request failed
 *          showcase the issue
 *
 * Input: None
 *
 * Output: None
 *
 * Side-Effects: Displays the response data
 *
**********************************************************************/
SurfaceResponse:

  Say
  Say 'Rexx RC: (' || Arg(1) || ')'

  /*
   * Continue processing even if RC <> 0 because additional information
   * could have been returned in the response to help understand the
   * error
   */

  Say 'HTTP Status: (' || response.httpstatus || ')'
  successIndex = Index(response.httpstatus, '2')

  /* SE responded successfully */
  If successIndex = 1 Then Do
    Say 'SE DateTime: (' || response.responsedate || ')'
    Say 'SE requestId: (' || response.requestId || ')'

    If response.httpstatusNum = '201' Then
      Say 'Location Response: (' || response.location || ')'

    If  response.responsebody <> '' Then Do
      Say 'Response Body: (' || response.responsebody || ')'
      Return response.responsebody
    End
  End
  Else Do
    Say 'Reason Code: (' || response.reasoncode || ')'

    If response.responsedate <> '' Then
      Say 'SE DateTime: ('||response.responsedate||')'

    If response.requestId <> '' Then
      Say 'SE requestId: (' || response.requestId || ')'

    If response.responsebody <> '' Then Do
      Call ParseJSONData response.responsebody

      If RESULT <> 0 Then Do
        Say 'Failed to parse response'
      End
      Else Do

        bcpiiErr=FindJSONValue(0, "bcpii-error", HWTJ_BOOLEAN_TYPE)

        errMsg = 'SE generated error message:'

        If bcpiiErr = 'true' Then
          errMsg = 'BCPii generated error message:'

        Say errMsg

        errmessage = FindJSONValue(0,"message", HWTJ_STRING_TYPE)
        Say '(' || errmessage || ')'
        Say

        Say 'Complete Response Body: (' || response.responsebody || ')'
      End
    End
  End

Return ''

/**********************************************************************
 * Function: Usage
 *
 * Purpose: Provide Usage guidance to the invoker
 *
 * Input: whyString - A string describing why the user is receiving this
 *                    usage message
 *
 * Output: -1 to indicate fatal script error.
 *
 * Side-Effects:
 *
 *  1. Displays an informational message describing how one would use
 *     the script
 *
**********************************************************************/
Usage:
  whyString = Arg(1)
  Say
  Say 'Usage:'
  Say 'ex LSTGRPS [-C CPCName] [-L LPARName] [-G GroupName] '
  Say '           [-A Action {ADD, REMOVE}] [-I] [-V]'
  Say
  Say '   Optional:'
  Say '     -C CPCName,   is the name of the CPC of interest, default'
  Say '                   if not specified is the LOCAL CPC'
  Say '     -L LPARName,  is the name of the LPAR of interest, default'
  Say '                   if not specified is the LOCAL LPAR'
  Say '     -G GroupName, is the name of the custom user group'
  Say '                   to target'
  Say '     -A Action,    is the action to take against the user group,'
  Say '                   specify either ADD or REMOVE which will add '
  Say '                   or remove the target LPAR object id from the '
  Say '                   target user group members'
  Say '     -V,           turn on additional verbose JSON tracing'
  Say '     -I,           indicate running in an isv rexx, default if '
  Say '                   not specified is TSO/E REXX'
  Say
  Say '(' || whyString || ')'
  Say
Return -1