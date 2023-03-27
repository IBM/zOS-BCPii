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
 *    HEADER NAME= HWIJPRS                                             *
 *                                                                     *
 *  Header that contains function declarations used by hwijprs.cpp     *
 *                                                                     *
 **********************************************************************/
#include <hwtjic.h> /* JSON interface declaration file  */

extern bool init_parser();
extern bool parse_json_text(const char *jtext);
extern bool do_cleanup();
extern char *find_string(HWTJ_HANDLE_TYPE object, char *search_string);
extern char *find_number(HWTJ_HANDLE_TYPE object, char *search_string);
extern void *find_value(HWTJ_HANDLE_TYPE object_to_search, char *name,
                 HWTJ_JTYPE_TYPE expected_value_type);
extern void *do_get_value(HWTJ_HANDLE_TYPE *value_handle,
                   HWTJ_JTYPE_TYPE entry_type);
extern HWTJ_HANDLE_TYPE find_array(HWTJ_HANDLE_TYPE object,
                            char *search_string);
extern int getnumberOfEntries(HWTJ_HANDLE_TYPE starthandle);
extern HWTJ_HANDLE_TYPE getArrayEntry(HWTJ_HANDLE_TYPE arrayhandle,
                               int arrayindex);
extern void display_error(char *msg);

int do_get_boolvalue(HWTJ_HANDLE_TYPE value_handle);
int find_boolvalue(HWTJ_HANDLE_TYPE object_to_search, char *name);
