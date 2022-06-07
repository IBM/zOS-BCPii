## Example-Energy-REXX

This samples queries a CPC and lists the energy management attributes for that CPC. It stores the results, which are in .csv format, in a z/OS data set member.  You can import the content into Microsoft™ Excel or another application of your choice.

This samples uses **HWIREST API** to do the following:
- List CPCs and retrieve the URI and target name associated with the LOCAL CPC or the *CPCname* provided
- For the designated CPC, retrieve the following information:
     - cpc-power-rating
     - cpc-power-consumption
     - cpc-power-saving
     - cpc-power-saving-state
     - cpc-power-save-allowed
     - cpc-power-capping-state
     - cpc-power-cap-minimum
     - cpc-power-cap-maximum
     - cpc-power-cap-current
     - cpc-power-cap-allowed
     - zcpc-power-rating
     - zcpc-power-consumption
     - zcpc-power-saving
     - zcpc-power-saving-state
     - zcpc-power-save-allowed
     - zcpc-power-capping-state
     - zcpc-power-cap-minimum
     - zcpc-power-cap-maximum
     - zcpc-power-cap-current
     - zcpc-power-cap-allowed
     - zcpc-ambient-temperature
     - zcpc-exhaust-temperature
     - zcpc-humidity
     - zcpc-dew-point
     - zcpc-heat-load
     - zcpc-heat-load-forced-air
     - zcpc-heat-load-water
     - zcpc-maximum-potential-power
     - zcpc-maximum-potential-heat-load
     - last-energy-advice-time
     - zcpc-minimum-inlet-air-temperature
     - zcpc-maximum-inlet-air-temperature
     - zcpc-maximum-inlet-liquid-temperature
     - zcpc-environmental-class   


## System Prep work
- Store RXENRGY1 into a data set
- Ensure your z/OS user ID has at least READ access to the following FACILITY Class Profile
    - HWI.TARGET.netid.nau

    <p>where netid.nau represents the 3– to 17– character SNA name of the particular CPC whose energy management attributes are being queried.  </p>

- Allocate a partitioned data set that can hold the generated content
   - the longest lines generated is 797 characters long
   - minimum data set characteristics
     - RECFM: VB
     - LRECL: 800

## Invocation
**Syntax**:
```
  RXENRGY1 -D outputDataSet [-C CPCname] [-I] [-V]                                                    
 ```
 where:
  - *-D outputDataSet*
      - **required**
      - *outputDataSet* is the name of an existing partitioned data set
      - if the CPC query is successful, a member containing the energy
        information in a CSV format will be stored into the specified data set: *outputDataSet(memberName)*
        where the name of data set member is:
        - LOCAL, if the LOCAL CPC was used
        - CPCname, if a specific CPC was specified via the -C option
  - *-C CPCname*
      - **optional**
      - *CPCname* is the name of the CPC whose energy info will be queried
      - **default if not provided:** LOCAL CPC
  - *-I*
      - **optional**
      - indicates this exec is being run in an ISV REXX environment
      - **default if not set:** TSO/E REXX environment
  - *–V*
      - **optional**
      - indicates additional tracing associated with JSON parsing should be turned on
      - **default if not set:** tracing excludes JSON specific tracing

**sample invocation in TSO:**
<br>RXENRGY1 has been copied into data set HWI.HWIREST.REXX and HWI.RXENERGY.OUTPUT
    has been allocated as RECFM=VB, LRECL=800
```
ex 'HWI.HWIREST.REXX(RXENRGY1)' '-D HWI.RXENERGY.OUTPUT'
```
 - exec is running in a TSO/E rexx environment and will query the LOCAL CPC
```
ex 'HWI.HWIREST.REXX(RXENRGY1)' '-D HWI.RXENERGY.OUTPUT -C T256'
```
 - exec is running in a TSO/E rexx environment and will query CPC T256

**sample batch invocation via JCL:**
<br>RXENRGY1 has been copied into data set HWI.HWIREST.REXX and HWI.RXENERGY.OUTPUT
    has been allocated as RECFM=VB, LRECL=800

```
 //RXENRGY1 JOB ,
 // CLASS=J,NOTIFY=&SYSUID,MSGLEVEL=1,
 //  MSGCLASS=H,REGION=0M,TIME=1440
 //STEP1    EXEC PGM=IKJEFT01,DYNAMNBR=20
 //SYSUDUMP DD SYSOUT=(H,,STD)
 //SYSTSPRT DD SYSOUT=(H,,STD)
 //SYSTSIN  DD * UB
 PROFILE NOPREFIX
 EX 'HWI.HWIREST.REXX(RXENRGY1)' -
 '-D HWI.RXENERGY.OUTPUT -C T115'
 /*
 ```
 - exec is running in a TSO/E rexx environment and will query CPC T115

## Generated Output

 ![Sample ENERGY result](https://github.com/IBM/zOS-BCPii/blob/main/Example-Energy-REXX/images/SampleEnergyResult.png)
 - If no query results show up, ensure that
  1. Your USER ID has the appropriate access level to the FACILITY Class profile associated
     with that CPC, see **System Prep Work** above      
  2. Your local LPAR is allowed to use BCPii to access the CPC attributes
     [Setting BCPii firmware security access for each LPAR](https://www.ibm.com/docs/en/zos/2.5.0?topic=configuration-setting-bcpii-firmware-security-access-each-lpar)
