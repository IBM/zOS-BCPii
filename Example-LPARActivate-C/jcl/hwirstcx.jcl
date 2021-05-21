//HWIRSTCX JOB NOTIFY=&SYSUID,
// CLASS=J,MSGLEVEL=1,MSGCLASS=H
/*JOBPARM SYSAFF=???
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
//*---------------------------------------------
//* Sample JCL to COMPILE AND BIND A C++ PROGRAM
//*---------------------------------------------
//* OFFICIAL COMPILER FOR C++ PROGRAMS
//         JCLLIB ORDER=(CBC.SCCNPRC)
//* Location of c++ source and listings datasets
//  SET INPUTCDS=hlq.HWIREST.CPP
//  SET LISTDS=hlq.HWIREST.LISTCPP
//*---------------------------------------------
//* COMPILE HWIJPRS, which HWIRSTC1 will include
//*---------------------------------------------
//STEP1    EXEC CBCC,
//         OUTFILE='hlq.PDSE.LOAD,DISP=SHR',
//         CPARM='LO SO XREF LIST DLL OPTFILE(DD:MYOPT) LOCALE'
//COMPILE.SYSCPRT DD DSN=&LISTDS,DISP=SHR
//COMPILE.SYSIN  DD DSN=&INPUTCDS(HWIJPRS),DISP=SHR
//*
//COMPILE.MYOPT DD  *
     OBJECT('hlq.HWIREST.OBJ')
     DEF(_XOPEN_SOURCE_EXTENDED=1,_OPEN_MSGQ_EXT,MVS,SCLPAIB)
     LSEARCH('hlq.HWIREST.H')
     SEARCH('SYS1.SIEAHDRV.H')
/*
//*---------------------------------------------
//* COMPILE and BIND HWIRSTC1
//*---------------------------------------------
//STEP2    EXEC CBCCB,
//         OUTFILE='hlq.PDSE.LOAD,DISP=SHR',
//         CPARM='LO SO XREF LIST DLL OPTFILE(DD:MYOPT) LOCALE'
//COMPILE.SYSCPRT DD DSN=&LISTDS,DISP=SHR
//COMPILE.SYSIN  DD DSN=&INPUTCDS(HWIRSTC1),DISP=SHR
//*
//COMPILE.MYOPT DD  *
     OBJECT('hlq.HWIREST.OBJ')
     DEF(_XOPEN_SOURCE_EXTENDED=1,_OPEN_MSGQ_EXT,MVS,SCLPAIB)
     LSEARCH('hlq.HWIREST.H')
     SEARCH('SYS1.SIEAHDRV.H')
//BIND.TESTOBJ  DD  DSN=hlq.HWIREST.OBJ,DISP=SHR
//BIND.SYSOBJ   DD  DSN=SYS1.CSSLIB,DISP=SHR
//BIND.SYSIN    DD  *
   INCLUDE TESTOBJ(HWIJPRS)
   INCLUDE TESTOBJ(HWIRSTC1)
   INCLUDE SYSOBJ(HWICSS)
   INCLUDE SYSOBJ(HWTJCSS)
   ENTRY CEESTART
   SETCODE AC(1)
   NAME HWIRSTC1(R)
/*
