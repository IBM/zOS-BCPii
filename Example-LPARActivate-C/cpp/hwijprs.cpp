/* START OF SPECIFICATIONS *********************************************
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
 *    MODULE NAME= HWIJPRS                                             *
 *                                                                     *
 *  Sample C code that defines utility like methods for parsing        *
 *  and retrieving various properties from JSON text.                  *
 *                                                                     *
 *  See the z/OS MVS Programming: Callable Services for                *
 *  High-Level Languages publication for more information              *
 *  regarding the usage of JSON Parser APIs.                           *
 *                                                                     *
 *************************END OF SPECIFICATIONS************************/
#pragma filetag("IBM-1047")    /* compile in EBCDIC */
#pragma csect(code, "HWIJPRS") /* name of csect */
#pragma longName
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <hwtjic.h> /* JSON interface declaration file  */
#include "hwijprs.h"

/* parser global variables */
/* Used to specify the max work area size to parser init service (hwtjinit). */
#define MAX_WORKAREA_SIZE 0 /* Zero = No limit (IBM recommended value) */

/* A parser instance is required for all JSON callable services. */
HWTJ_PARSERHANDLE_TYPE parser_instance;

/* A structure for storing reason codes and error descriptions. */
HWTJ_DIAGAREA_TYPE diag_area;

/* A return code to store the result of each service call. */
int jpreturncode;

/*
 * Method: init_parser
 *
 * Initializes the global parser_instance variable.
 *
 * Services Used:
 *
 *    HWTJINIT: Provides a handle to a parse instance which is then used in
 *              subsequent service calls. The HWTJINIT service must be invoked
 *              before invoking any other parsing service.
 */
bool init_parser()
{

  /* Declare a variable to hold the return value. */
  bool success = false;

  /* Initialize the parser work area and retrieve a handle to a parser
   * instance.
   */
  hwtjinit(&jpreturncode,
           MAX_WORKAREA_SIZE, /* size (in bytes) of the parser work area (input) */
           parser_instance,
           &diag_area);

  if (jpreturncode == HWTJ_OK)
  {
    printf("SUCCESS: Parser initialized.\n");
    success = true;
  }
  else
  {
    display_error("Parser initialization failed.");
  }

  return success;
}

/*
 * Method: parse_json_text
 *
 * Parses the sample JSON data.
 *
 * Services Used:
 *
 *    HWTJPARS: Builds an internal representation of the specified JSON string.
 *              This allows efficient search, traversal, and modification of
 *              the JSON data.
 *
 *    USAGE:   HWTJPARS does not make a local copy of the JSON source string.
 *             Therefore, the caller must ensure that the provided source
 *             string remains unmodified for the duration of the parser
 *             instance. If the source string is modified, subsequent service
 *             calls may result in unexpected behavior.
 */
bool parse_json_text(const char *jtext)
{

  /* Declare a variable to hold the return variable. */
  bool success = false;

  /* Parse the sample JSON text string. Parse scans the JSON text string and
   * creates an internal representation of the JSON data suitable for search
   * and create operations.
   */
  hwtjpars(&jpreturncode,
           parser_instance,
           (char *)&jtext, /* JSON text string address(input) */
           strlen(jtext),  /* JSON text string length (input) */
           &diag_area);

  if (jpreturncode == HWTJ_OK)
  {
    success = true;
  }
  else
  {
    display_error("Unable to parse JSON data.");
  }

  return success;
}

/*
 * Method: find_string
 *
 * Searches the specified JSON object for a name:value pair where the name
 * matches the specified search string and the value type is string. This is a
 * convenience method that can be used when the structure of the JSON data is
 * known beforehand.
 *
 * Input:  - A handle of type object or array.
 *         - A string used as the search parameter.
 *
 * Output: If a match is found, the string value of the name:value pair is
 *         returned.
 */
char *find_string(HWTJ_HANDLE_TYPE object, char *search_string)
{
  return (char *)find_value(object, search_string, HWTJ_STRING_TYPE);
}

/*
 * Method: find_number
 *
 * Searches the specified JSON object for a name:value pair where the name
 * matches the specified search string and the value type is number. This is a
 * convenience method that can be used when the structure of the JSON data is
 * known beforehand.
 *
 * Input:  - A handle of type object or array.
 *         - A string used as the search parameter.
 *
 * Output: If a match is found, the number value of the name:value pair is
 *         returned.
 *
 * Notes: The JSON spec (RFC 4627) allows numbers to be specified in several
 * different formats (e.g. 3.00, 3.0e+2). This sample program makes no effort
 * to convert JSON numeric data into the appropriate C data type -- all numeric
 * data is treated as string data.
 */
char *find_number(HWTJ_HANDLE_TYPE object, char *search_string)
{
  return (char *)find_value(object, search_string, HWTJ_NUMBER_TYPE);
}

/*
 * Method: find_value
 *
 * Searches the specified object for a name:value pair whose name matches the
 * the specified search string. This is a utility method used by the "find"
 * routines to easily search and retrieve a value from an object when the name
 * and value type is known.
 *
 * Input:  - A handle of type object or array.
 *         - A string used as a search parameter.
 *         - A JSON type as defined in the IBM-provided C interface definition
 *           file.
 *
 * Output: A pointer to the value is returned.
 *
 * Services Used:
 *    HWTJGJST: Gets the JSON type associated with a specified object or entry
 *              handle.
 *    HWTJSRCH: Finds a particular name string within the JSON text.
 *
 */
void *find_value(HWTJ_HANDLE_TYPE object_to_search, char *name,
                 HWTJ_JTYPE_TYPE expected_value_type)
{

  /* Declare a handle to store a pointer to value. */
  void *value_addr = NULL;

  /* Declare a variable to hold the value if a match is found. */
  HWTJ_HANDLE_TYPE value_handle = 0;

  /* Search the specified object for the specified name. */
  hwtjsrch(&jpreturncode,
           parser_instance,
           HWTJ_SEARCHTYPE_OBJECT, /* limit the search scope */
           (char *)&name,          /* search string address */
           strlen(name),           /* search string length */
           object_to_search,       /* handle of object to search */
           0,                      /* starting point of the search */
           &value_handle,          /* search result handle (output) */
           &diag_area);

  /* Check that the search found a result. */
  if (jpreturncode == HWTJ_OK)
  {
    /* Declare a variable to hold the entry type returned by hwtjgjst. */
    HWTJ_JTYPE_TYPE entry_type;

    /* Get the object's type. */
    hwtjgjst(&jpreturncode,
             parser_instance,
             value_handle, /* handle to the value whose type to check (input) */
             &entry_type,  /* value type constant returned by hwtjgjst (output) */
             &diag_area);

    if (jpreturncode == HWTJ_OK)
    {
      /* Verify that the returned handle has the expected type. */
      if (entry_type == expected_value_type)
      {
        value_addr = do_get_value(&value_handle, entry_type);
      }
      else
      {
        printf("Error occurred while searching for %s\nThe name was found, "
               "but the value was not of the expected type.\n",
               name);
        printf("Expected type: %d\nActual type: %d\n",
               expected_value_type, entry_type);
      }
    }
    else
    {
      display_error("ERROR: Unable to retrieve JSON type.");
    }
  }
  else
  {
    printf("ERROR: Search failed for name \"%s\". "
           "Name was not found in the specified object.\n",
           name);
  }

  /*
   * At this point, if the search did not return a match, or the
   * expected type did not match the actual type, the value_addr
   * output parm is still set to NULL. Otherwise, value_addr
   * points to the appropriate address. The caller is responsible
   * for casting the void pointer to the appropriate pointer type.
   */
  return value_addr;
}

/*
 * Method: find_value
 *
 * Searches the specified object for a name:value pair whose name matches the
 * the specified search string. This is a utility method used by the "find"
 * routines to easily search and retrieve a value from an object when the name
 * and value type is known.
 *
 * Input:  - A handle of type object or array.
 *         - A string used as a search parameter.
 *         - A JSON type as defined in the IBM-provided C interface definition
 *           file.
 *
 * Output:
 *  -1 if value not obtained,
 *   0 if bool is FALSE,
 *   1 if bool is TRUE
 *
 * Services Used:
 *    HWTJGJST: Gets the JSON type associated with a specified object or entry
 *              handle.
 *    HWTJSRCH: Finds a particular name string within the JSON text.
 *
 */
int find_boolvalue(HWTJ_HANDLE_TYPE object_to_search, char *name)
{

  HWTJ_JTYPE_TYPE expected_value_type = HWTJ_BOOLEAN_TYPE;

  /* Declare a handle to store a pointer to value. */
  int boolResult = -1;

  /* Declare a variable to hold the value if a match is found. */
  HWTJ_HANDLE_TYPE value_handle = 0;

  /* Search the specified object for the specified name. */
  hwtjsrch(&jpreturncode,
           parser_instance,
           HWTJ_SEARCHTYPE_OBJECT, /* limit the search scope */
           (char *)&name,          /* search string address */
           strlen(name),           /* search string length */
           object_to_search,       /* handle of object to search */
           0,                      /* starting point of the search */
           &value_handle,          /* search result handle (output) */
           &diag_area);

  /* Check that the search found a result. */
  if (jpreturncode == HWTJ_OK)
  {

    /* Declare a variable to hold the entry type returned by hwtjgjst. */
    HWTJ_JTYPE_TYPE entry_type;

    /* Get the object's type. */
    hwtjgjst(&jpreturncode,
             parser_instance,
             value_handle, /* handle to the value whose type to check (input) */
             &entry_type,  /* value type constant returned by hwtjgjst (output) */
             &diag_area);

    if (jpreturncode == HWTJ_OK)
    {

      /* Verify that the returned handle has the expected type. */
      if (entry_type == expected_value_type)
      {
        boolResult = do_get_boolvalue(value_handle);
      }
      else
      {
        printf("Error occurred while searching for %s\nThe name was found, "
               "but the value was not of the expected type.\n",
               name);
        printf("Expected type: %d\nActual type: %d\n",
               expected_value_type, entry_type);
      }
    }
    else
    {
      display_error("ERROR: Unable to retrieve JSON type.");
    }
  }
  else
  {
    printf("ERROR: Search failed for name \"%s\". "
           "Name was not found in the specified object.\n",
           name);
  }

  return boolResult;
}

/*
 * Method: do_get_boolvalue
 *
 * -1 if value not obtained,
 *  0 if bool is FALSE,
 *  1 if bool is TRUE
 *
 * Input: - A value handle.
 *
 * Services Used:
 *    HWTJGBOV: Retrieves the value of a boolean entry.
 */
int do_get_boolvalue(HWTJ_HANDLE_TYPE value_handle)
{

  /* In the case of a boolean value type, the HWTJ_TRUE/HWTJ_FALSE
   * value is converted to a bool type and the value_addr output
   * parm is set to the address of the bool value.
   *
   * In the case of an object or array type, the value_addr output
   * parm is set to the address of the object or array handle.
   */

  /* Declare a variable to store the value returned by hwtjgbov. */
  HWTJ_BOOLEANVALUE_TYPE hwtj_boolean;
  int boolResponse = -1; //not found

  /* Retrieve the value and store it in a local variable. */
  hwtjgbov(&jpreturncode,
           parser_instance,
           value_handle,  /* handle to the value (input) */
           &hwtj_boolean, /* boolean value returned by hwtjgbov (output) */
           &diag_area);

  if (jpreturncode == HWTJ_OK)
  {
    if (hwtj_boolean == HWTJ_TRUE)
    {
      boolResponse = 1;
    }
    else if (hwtj_boolean == HWTJ_FALSE)
    {
      boolResponse = 0;
    }
    else
    {
      printf("bool value not recognized\n");
    }
  }
  else
  {
    display_error("Unable to retrieve boolean value.");
  }

  return boolResponse;
}

/*
 * Method: do_get_value
 *
 * Retrieves the specified value by calling the appropriate service using the
 * value of the specified HWTJ_JTYPE_TYPE.
 *
 * Input: - A value handle.
 *        - A valid entry type as defined in the IBM-provided C interface
 *          definition file.
 *
 * Services Used:
 *    HWTJGVAL: Retrieves the value of string or number entry.
 *    HWTJGBOV: Retrieves the value of a boolean entry.
 */
void *do_get_value(HWTJ_HANDLE_TYPE *value_handle,
                   HWTJ_JTYPE_TYPE entry_type)
{

  /* Declare a variable to hold the pointer to the copy. */
  void *value_addr = NULL;

  /*
   * The following checks determine the value's type and set
   * the value_addr output parm appropriately.
   *
   * In the case of a string or number type, the source text is
   * copied into a new buffer, and the value_addr output parm is
   * set to the address of this buffer.
   *
   * In the case of a boolean value type, the HWTJ_TRUE/HWTJ_FALSE
   * value is converted to a bool type and the value_addr output
   * parm is set to the address of the bool value.
   *
   * In the case of an object or array type, the value_addr output
   * parm is set to the address of the object or array handle.
   */

  /* Determine the value type. */
  if ((entry_type == HWTJ_STRING_TYPE) ||
      (entry_type == HWTJ_NUMBER_TYPE))
  {

    /* Declare a variable to store the length returned by hwtjgval. */
    int value_length = 0;
    /* Declare a variable to store the address returned by hwtjgval. */
    int string_value_addr = 0;

    /* Issue hwtjgval to get the address and length of the string. */
    hwtjgval(&jpreturncode,
             parser_instance,
             *value_handle,      /* handle to a value (input) */
             &string_value_addr, /* value address (output) */
             &value_length,      /* returned value length (output) */
             &diag_area);

    if (jpreturncode == HWTJ_OK)
    {
      /* Allocate memory to store a copy of the string + null terminator. */
      value_addr = malloc(value_length + 1);

      /* Copy the JSON source text to the local variable. */
      strncpy((char *)value_addr, (char *)string_value_addr, value_length);

      /* Append the null-terminator. */
      ((char *)value_addr)[value_length] = '\0';

      if (entry_type == HWTJ_NUMBER_TYPE)
      {

        int num_value = 0;
        int *num_value_ptr = &num_value;
        HWTJ_VALDESCRIPTOR_TYPE value_desc = 0;

        /* Issue HWTJGNUV to get the binary representation
                * of the number value.
                */
        hwtjgnuv(&jpreturncode,
                 parser_instance,
                 *value_handle,
                 &num_value_ptr,    /* pointer to output buffer */
                 sizeof(num_value), /* size of output buffer */
                 &value_desc,       /* indicates 2's comp or BFP */
                 &diag_area);

        if (jpreturncode == HWTJ_OK)
        {

          /* Verify that the converted value is an integer type.
                     This check can be skipped if you are confident that
                     the numeric data will only be specified as integer
                     data.
                    */
          if (value_desc == HWTJ_INTEGER_VALUE && num_value >= 10)
          {
          }
        }
        else
        {
          display_error("An error occurred in Do_Get_Value. "
                        "HWTJGNUV failed.");
        }
      }
    }
    else
    {
      printf("logic error, use do_get_boolvalue() for booleans\n");
    }
  }
  else if (entry_type == HWTJ_BOOLEAN_TYPE)
  {

    display_error("Unable to retrieve boolean value.");
  }
  else if ((entry_type == HWTJ_ARRAY_TYPE) ||
           (entry_type == HWTJ_OBJECT_TYPE))
  {

    /* Store the address of the handle in our return variable. */
    value_addr = value_handle;
  }

  return value_addr;
}

/*
 * Method: find_array
 *
 * Searches the specified JSON object for a name:value pair where the name
 * matches the specified search string and the value type is array. This is a
 * convenience method that can be used when the structure of the JSON data is
 * known beforehand.
 *
 * Input:  - A handle of type object or array.
 *         - A string used as the search parameter.
 *
 * Output: If a match is found, a handle to the array value of the name:value
 *         pair is returned.
 */
HWTJ_HANDLE_TYPE find_array(HWTJ_HANDLE_TYPE object, char *search_string)
{
  HWTJ_HANDLE_TYPE *array_handle_addr =
      (HWTJ_HANDLE_TYPE *)find_value(object, search_string, HWTJ_ARRAY_TYPE);
  return *array_handle_addr;
}

/*
 * Method: getArrayEntry
 *
 * Retrieve a handle to the specific array entry index.
 * This is a zero-origin index, meaning that the first entry
 * in the array has an index of zero; the nth entry has an
 * index of (n  1).
 *
 * Input:  - A handle of type array
 *         - The requested entry index
 *
 * Output: If a match is found, a handle to the array entry is returned.
 */
HWTJ_HANDLE_TYPE getArrayEntry(HWTJ_HANDLE_TYPE arrayhandle, int arrayindex)
{

  HWTJ_HANDLE_TYPE arrayentryhandle;
  hwtjgaen(
      &jpreturncode,
      parser_instance,
      arrayhandle,
      arrayindex,
      &arrayentryhandle,
      &diag_area);

  if (jpreturncode == HWTJ_OK)
  {
    return arrayentryhandle;
  }
  else
  {
    display_error("Failure retrieve array entry handle\n");
    return -1;
  }
}

/*
 * Method: getnumberOfEntries
 *
 * Retrieve the number of entries in the object
 *
 * Input:  - A handle to the object which contains the entries
 *
 * Output: Number of entries
 */
int getnumberOfEntries(HWTJ_HANDLE_TYPE starthandle)
{

  /* starting point */
  int numofentries;

  hwtjgnue(&jpreturncode,
           parser_instance,
           starthandle,
           &numofentries,
           &diag_area);

  if (jpreturncode == HWTJ_OK)
  {
    return numofentries;
  }
  else
  {
    display_error("Failure to retrieve num of entries\n");
    return -1;
  }
}

/*
 * Method: do_cleanup
 *
 * Performs cleanup by freeing memory used by the parser and invalidating the
 * parser handle.
 *
 * Services Used:
 *
 *    HWTJTERM: Terminates a parser instance and frees the storage allocated
 *              by the parse services.
 *
 *    USAGE:    The third parameter to hwtjterm is used to specify the
 *              behavior of terminate if the parser is determined to be stuck
 *              in an "in-use" state. IBM recommends using the HWTJ_NOFORCE
 *              option in most cases. Because our sample is not multi-threaded,
 *              the risk of the parser getting stuck in an "in-use" state is
 *              low. Therefore, we provide a value of HWTJ_NOFORCE for the
 *              force option.
 *
 *    NOTE: Consider enhancing this sample to postpone the call to the
 *    terminate service when a prior service call resulted in a return code of
 *    HWTJ_UNEXPECTED_ERROR. This will allow appropriate action to be taken to
 *    dump the work area storage for subsequent analysis by the IBM support
 *    center. Once the dump has been taken, terminate can be issued to free the
 *    storage from the user's address space.
 */
bool do_cleanup()
{

  /* Declare a variable to hold the return value. */
  bool success = false;

  /*
   * On the first attempt, try to terminate with the force option disabled.
   * This is the IBM recommended value for the force option. If the parser is
   * in an inuse state, further cleanup processing is done in the following
   * EVALUATE statement. A parser can be in an INUSE state if a prior service
   * call encountered an unexpected error that caused it to exit abnormally, or
   * if the parser-handle is used in a multi-threaded application.
   */
  if (jpreturncode != HWTJ_PARSERHANDLE_INUSE)
  {
    /* Perform cleanup. */
    hwtjterm(&jpreturncode, parser_instance, HWTJ_NOFORCE, &diag_area);
  }

  /* Determine whether further cleanup processing is necessary. */
  switch (jpreturncode)
  {
  case HWTJ_OK:
    printf("SUCCESS: Parser work area freed.\n");
    success = true;
    break;
  case HWTJ_PARSERHANDLE_INUSE:
    display_error("Unable to perform cleanup.\n "
                  "Retrying cleanup with HWTJ_FORCE option enabled.");

    /* Attempt to force cleanup. Use with caution as recommended in the
       * parser documentation
       */
    hwtjterm(&jpreturncode, parser_instance, HWTJ_FORCE, &diag_area);

    /* Check if cleanup was successful. */
    if (jpreturncode == HWTJ_OK)
    {
      printf("SUCCESS: Parser work area freed using force option.\n");
      success = true;
    }
    else
    {
      display_error("Unable to perform cleanup with HWTJ_FORCE option "
                    "enabled.\nCould not free parser work area.");
    }
    break;
  default:
    display_error("Unable to perform cleanup.\n "
                  "Could not free parser work area.");
  }

  return success;
}

/*
 * Method: display_error
 *
 * A helper method for displaying error diagnostic information.
 */
void display_error(char *msg)
{
  printf("ERROR: %s\n", msg);
  printf("Return Code: %d\n", jpreturncode);
  printf("Reason Code: %d\n", diag_area.ReasonCode);
  printf("Reason Text: %s\n", diag_area.ReasonDesc);
}
