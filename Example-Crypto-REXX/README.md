## Example-Crypto-REXX

This sample retrieves crypto information from image activation profiles associated with LPARs located on a specific CPC. It stores the results, which are in .csv format, in a z/OS data set member.  You can import the content into Microsoft™ Excel or another application of your choice.

This sample uses **HWIREST API** to do the following:
- List CPCs and retrieve the URI and target name associated with the
 LOCAL CPC (default) or the *CPCname* provided
- List the LPARs on the designated CPC
- For each LPAR matching the requested status (default is operating), access the image activation profile with the same name as the LPAR to rerieve the 
following information:
     - crypto-activity-cpu-counter-authorization-control
     - assigned-crypto-domains
     - assigned-cryptos
- <b>Note: </b>
 The crypto attributes are available on z16 or higher processors only.

## System Prep work
- Store RXCRYPT1 into a data set
- Ensure your z/OS user ID has at least READ access to the following FACILITY Class Profiles
    - HWI.TARGET.netid.nau
    - HWI.TARGET.netid.nau.imagename

    <p>where netid.nau represents the 3– to 17– character SNA name of the particular CPC whose LPARs are being queried and imagename represents the 1– to 8- character LPAR name, or * to represent all of the LPARs available on that CPC </p>

- Allocate a partitioned data set that can hold the generated content
   - the longest line generated depends on how many assigned-crypto-domains and assigned-cryptos are found
   - minimum data set characteristics
     - RECFM: VB
     - LRECL: 800

## Invocation
**Syntax**:
```
  RXCRYPT1 -D outputDataSet [-C CPCname] [-S Status] [-I] [-V]                                                
 ```
 where:
  - *-D outputDataSet*
      - **required**
      - *outputDataSet* is the name of an existing partitioned data set
      - if the query is successful, a member containing the crypto
        information in a CSV format will be stored into the specified data set: *outputDataSet(memberName)* where the name of data set member is:
        - LOCAL, if the LOCAL CPC was used
        - CPCname, if a specific CPC was specified via the -C option
  - *-C CPCname*
      - **optional**
      - *CPCname* is the name of the CPC which hosts the LPARs whose corresponding image activation profile crypto info will be retrieved
      - **default if not provided:** LOCAL CPC
  - *-S Status*
      - **optional**
      - *Status* represents the status of the LPAR and is an optional filter for the list of LPARs. The names associated with these LPARs is used as input for which image activation profiles need to be queried.
      - Valid values:          
        - operating - query profiles for activation image profiles
        associated with active/operating LPARs  
        - not-operating - query profiles for activation image profiles
        associated with with active/not operating LPARs                                                  
        - not-activated - query profiles for activation images profiles
        associated with not-activated LPARs 
      - **default if not provided or if not valid:** operating                                               
  - *-I*
      - **optional**
      - indicates this exec is being run in an ISV REXX environment
      - **default if not set:** TSO/E REXX environment
  - *–V*
      - **optional**
      - indicates additional tracing associated with JSON parsing should be turned on
      - **default if not set:** tracing excludes JSON specific tracing

**sample invocation in TSO:**
<br>RXCRYPT1 has been copied into data set HWI.HWIREST.REXX and HWI.RXCRYPTO.OUTPUT
    has been allocated as RECFM=VB, LRECL=800
```
ex 'HWI.HWIREST.REXX(RXCRYPT1)' '-D HWI.RXCRYPTO.OUTPUT'
```
 - exec is running in a TSO/E rexx environment and will query the crypto information associated with LPARs in operating status on the LOCAL CPC
```
ex 'HWI.HWIREST.REXX(RXCRYPT1)' '-D HWI.RXCRYPTO.OUTPUT -C CPC1'
```
 - exec is running in a TSO/E rexx environment and will query the crypto information associated with LPARS in operating status on CPC CPC1
 ```
ex 'HWI.HWIREST.REXX(RXCRYPT1)' '-D HWI.RXCRYPTO.OUTPUT -C CPC1 -S not-activated'
```
 - exec is running in a TSO/E rexx environment, will query the crypto information associated with LPARs in not-activated status on CPC CPC1

**sample batch invocation via JCL:**
<br>RXCRYPT1 has been copied into data set HWI.HWIREST.REXX and HWI.RXCRYPTO.OUTPUT
    has been allocated as RECFM=VB, LRECL=800

```
 //RXCRYPT1 JOB ,
 // CLASS=J,NOTIFY=&SYSUID,MSGLEVEL=1,
 //  MSGCLASS=H,REGION=0M,TIME=1440
 //STEP1    EXEC PGM=IKJEFT01,DYNAMNBR=20
 //SYSUDUMP DD SYSOUT=(H,,STD)
 //SYSTSPRT DD SYSOUT=(H,,STD)
 //SYSTSIN  DD * 
 PROFILE NOPREFIX
 EX 'HWI.HWIREST.REXX(RXCRYPT1)' -
 '-D HWI.RXCRYPTO.OUTPUT -C CPC1'
 /*
 ```
 - exec is running in a TSO/E rexx environment and will query will query the crypto information associated with LPARS in operating status on CPC CPC1

## Generated Output

 ![Sample crypto result](images/SampleCryptoResult.png)
 - If no query results show up, ensure that
  1. Your USER ID has the appropriate access level to the FACILITY Class profile associated with that CPC and imagename, 
  see **System Prep Work** above.    
  2. Your local LPAR is allowed to use BCPii to access the CPC attributes
     [Setting BCPii firmware security access for each LPAR](https://www.ibm.com/docs/en/zos/2.5.0?topic=configuration-setting-bcpii-firmware-security-access-each-lpar)
  3. You are running on a z16 processor or higher.
