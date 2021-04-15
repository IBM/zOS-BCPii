//*******************************************************************
//*
//* Copyright 2021 IBM Corp.
//*
//* Licensed under the Apache License, Version 2.0 (the "License");
//* you may not use this file except in compliance with the License.
//* You may obtain a copy of the License at
//*
//* http://www.apache.org/licenses/LICENSE-2.0
//*
//* Unless required by applicable law or agreed to in writing,
//* software distributed under the License is distributed on an
//* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//* either express or implied.  See the License for the specific
//* language governing permissions and limitations under the License.
//*******************************************************************
//*--------------------------------------
//* Sample JCL to execute the program
//*--------------------------------------
//HWIRSTC1 JOB CLASS=J,MSGLEVEL=(2,1),REGION=0K,MSGCLASS=H
/*JOBPARM SYSAFF=???
//HWIRSTC1  EXEC PGM=HWIRSTC1,
//    PARM='POSIX(ON),MSGFILE(SYSOUT) / CPCname LPARname'
//STEPLIB  DD DSN=hlq.PDSE.LOAD,DISP=SHR
//SYSPRINT DD SYSOUT=*
//CEEDUMP  DD SYSOUT=*
//SYSUDUMP DD SYSOUT=*