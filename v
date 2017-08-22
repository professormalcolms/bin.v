#!/bin/bash

# see https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/
# see http://tuxtweaks.com/2014/05/bash-getopts/
# see http://wiki.bash-hackers.org/howto/getopts_tutorial


# Set fonts for Help.
#
NORM=`tput sgr0`
BOLD=`tput bold`
REV=`tput smso`


# Primary wrapper. This allows me to toss all my function
# definitions to the bottom of this file.
#
main()
{
  #Check the number of arguments. If none are passed, print help and exit.
  #
  NUMARGS=$#
  if [ $NUMARGS -eq 0 ]; then
    BRIEFHELP
  fi

  
  # Re-EXEC a previous CMD if I am invoking the command using
  # a number only, as in 'v #' style.
  #
  if [[ $1 =~ ^[0-9]+$ ]] ; then
      exec `grep "CMDLINE:" $1*RESULTS| cut -d ':' -f 2`
  fi


  # Set Script Name variable
  # you want to grab the full command expression early
  # before you scrape off each respective parameter
  #
  SCRIPT=`basename ${BASH_SOURCE[0]}`
  CMD_ORIGINAL="$SCRIPT $*"


  #Initialize variables to default values.
  #
  OPT_Q=
  OPT_P=
  OPT_D=dumpfiles
  OPT_N=
  OPT_S=dumpfiles
  
  ### Start getopts code ###

  #If an option should be followed by an argument, it should be followed by a ":".
  #Notice there is no ":" after "h". The leading ":" suppresses error messages from
  #getopts. This is required to get my unrecognized option code to work.

  while getopts :s:p:d:n:hq OPT; do
    case $OPT in
      d)
        OPT_D=$OPTARG
        ;;
      h)
        HELP
        ;;
      n)
        OPT_N=.$OPTARG
        ;;
      p)
        VOPT_P="--pid=$OPTARG"
        OPT_P=.$OPTARG
        ;;
      q)
        OPT_Q=QUIET
        ;;
      s)
        OPT_S=$OPTARG
        ;;
      \?) #unrecognized option - show help
        echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
        HELP
        ;;
    esac
  done
  
  shift $((OPTIND-1))  #This tells getopts to move on to the next argument.
  
  ### End getopts code ###
  
  
  # Exit if we are missing required files
  #
  if [ ! -e mem ] || [ ! -h mem ]; then
      EXIT_ON_MESSAGE "ERROR:" "Missing mem file or symbolic link for mem"
  fi
  
  if [ ! -z $OPT_N ]  && [ -z $OPT_P ] ; then
      EXIT_ON_MESSAGE "ERROR:" "If you set option -n, then you must set option -p"
  fi
  
  if [ ! -z $OPT_P ]  && [ -z $OPT_N ] ; then
      EXIT_ON_MESSAGE "ERROR:" "If you set option -p, then you must set option -n"
  fi
  
  
  # Grab our PLUGIN, change to lowercase, and move on ...
  #
  PLUGIN=$( echo "$1" | tr '[:upper:]' '[:lower:]' )
  
  
  # Make sure we have a file 'profiles' before we commit to anything
  #
  if [ ! -z $PLUGIN ] && [ "$PLUGIN" != "imageinfo" ]  && [ ! -e profiles ] ; then
      EXIT_ON_MESSAGE "ERROR:" "Must create profile first: 'v imageinfo'"
  fi
  
  
  # Pre-Processing, as needed per type of PLUGIN
  #
  case $PLUGIN in
  
      dumpfiles)
          if [ -z $OPT_S ] ; then
              EXIT_ON_MESSAGE "ERROR:" "For plugin DUMPFILES, you must set summary name option -s"
          fi
          if [ -z $OPT_D ] ; then
              EXIT_ON_MESSAGE "ERROR:" "For plugin DUMPFILES, you must set option -d$"
          fi
          ;;
  
      *)
          ;;
  
  esac
  
  
  # Create certain files as we need them
  #
  if [ ! -e cnt ] ; then
      CONTINUE_ON_MESSAGE "INFO:" "Creating file 'cnt'"
      echo 1 > cnt
  fi
  
  if [ ! -e mem.md5 ]; then
      CONTINUE_ON_MESSAGE "INFO:" "Creating MD5 for mem as 'mem.md5'"
      md5sum mem > mem.md5
  fi
  
  
  # Update our counter for our tests
  #
  TAG=`cat cnt`
  echo $((TAG+1)) > cnt
  
  
  # Create the RESULTS file, specific to a
  # process (-p) if appropriate
  #
  RESULTS=$TAG
  if [ ! -z $OPT_N ]; then
      RESULTS=$RESULTS$OPT_N
  fi
  if [ ! -z $OPT_P ]; then
      RESULTS=$RESULTS$OPT_P
  fi
  RESULTS=$RESULTS.$PLUGIN.RESULTS
  
  
  # Record each of CMDLINE, PLUGINS, RESULTS, and MEMORY
  #
  echo "COUNT: $TAG" | tee -a $RESULTS
  echo "CMDLINE: $CMD_ORIGINAL" | tee -a $RESULTS
  echo "PLUGIN: $PLUGIN" | tee -a $RESULTS
  echo "RESULTS: $RESULTS" | tee -a $RESULTS
  echo "MEMORY: mem -> " `readlink mem` | tee -a $RESULTS
  echo "MEMORY MD5: " `cat mem.md5 | cut -d ' ' -f 1` | tee -a $RESULTS
  
  
  # Handle our expected PROFILE(S)
  #
  if [ "$PLUGIN" == "imageinfo" ] ; then
      PROFILE=""
      echo "PROFILE: none"  | tee -a $RESULTS
  else
      PROFILE=`cat profiles | cut -d "," -f 1`
      echo "PROFILE: $PROFILE"  | tee -a $RESULTS
      PROFILE=--profile=$PROFILE
  fi
  
  
  # Record -p option if provided
  #
  if [ ! -z $OPT_P ]; then
      echo "PROCESS: $OPT_P" | tee -a $RESULTS
  fi
  
  
  # Record -n option if provided
  #
  if [ ! -z $OPT_N ]; then
      echo "NAME: $OPT_N" | tee -a $RESULTS
  fi
  
  
  # Handle -d option for DIRECTORY RESULTS
  #
  if [ ! -z $OPT_D ] ; then
      DIR=$TAG${OPT_N}${OPT_P}.$PLUGIN.DIRECTORY
      echo "DIRECTORY: $DIR" | tee -a $RESULTS
      VOPT_D="--dump-dir=$DIR"
      rm -f $DIR
      mkdir $DIR
  else
      DIR=
      VOPT_D=
  fi
  
  
  # Handle -S option for SUMMARY
  #
  if [ ! -z $OPT_S ] ; then
      SUMMARY=$TAG$OPT_N$OPT_P.$PLUGIN.SUMMARY
      echo "SUMMARY: $SUMMARY" | tee -a $RESULTS
      VOPT_S="--summary-file=$SUMMARY"
  else
      VOPT_S=
  fi
  
  
  
  
  # Define command and evaluate
  #
  shift
  CMD="vol.py -f mem $PROFILE $PLUGIN $VOPT_P $VOPT_D $VOPT_S $*"
  echo "COMMAND: $CMD" | tee -a $RESULTS
  #
  echo | tee -a $RESULTS
  echo | tee -a $RESULTS
  echo "VOLATILITY PROCESSING" | tee -a $RESULTS
  echo "**************************************************" | tee -a $RESULTS
  eval $CMD 2>&1 | tee -a $RESULTS
  echo | tee -a $RESULTS
  echo | tee -a $RESULTS
  
  
  # Post-Processing, as needed per type of PLUGIN
  #
  case $PLUGIN in
      imageinfo)
          POST_CMD="grep -m 1 'Suggested Profile' $RESULTS | cut -d ':' -f 2 | tr -d '[:space:]' > profiles"
  
          echo "POST PROCESSING" | tee -a $RESULTS
          echo "**************************************************" | tee -a $RESULTS
          echo "POSTCMD: $POST_CMD" | tee -a $RESULTS
          
          eval $POST_CMD 2>&1 | tee -a $RESULTS
          ;;
  
      pslist)
          POST_CMD="grep '0xffff' $RESULTS | grep -v 'CMDLINE' | cut -c20-42 | count_words.pl | sort > $RESULTS.processes"
          
          echo "POST PROCESSING" | tee -a $RESULTS
          echo "**************************************************" | tee -a $RESULTS
          echo "POSTCMD: $POST_CMD" | tee -a $RESULTS
          
          eval $POST_CMD 2>&1 | tee -a $RESULTS
          ;;
          
      dumpfiles)
          POST_CMD="summary_to_json.pl $SUMMARY | python -m json.tool > $SUMMARY.JSON"
          POST_CMD2="summary_to_json.pl $SUMMARY | python -m json.tool | python ~/bin/dumpfile_extract.py > $SUMMARY.JSON.EXTRACT"
          
          echo "POST PROCESSING" | tee -a $RESULTS
          echo "**************************************************" | tee -a $RESULTS
          echo "POSTCMD: $POST_CMD" | tee -a $RESULTS
          echo "POSTCMD2: $POST_CMD2" | tee -a $RESULTS
          
          eval $POST_CMD 2>&1 | tee -a $RESULTS
          eval $POST_CMD2 2>&1 | tee -a $RESULTS
          ;;
  esac
  
  
  # Go quietly
  #
  if [ ! -z $OPT_Q ] ; then
    exit 0
  fi


  # When all is said and done offer to 'view' the results.
  #
  echo
  while true; do
      read -p "View results ... $RESULTS? (y/n): " yn
      case $yn in
          [Yy]* ) view $RESULTS; break;;
          [Nn]* ) exit;;
          * ) echo "Please answer yes or no.";;
      esac
  done
  

  # Cut bait
  #
  exit 0
}


###############################################################################################
#
# Output the Message, and then continue processing
#
###############################################################################################
function CONTINUE_ON_MESSAGE {
    if [ $# != 2 ] ; then
        echo
    else
        echo "${BOLD}$1${NORM} $2"
    fi
}


###############################################################################################
#
# Output the Message, but then exit.
#
###############################################################################################
function EXIT_ON_MESSAGE {
    if [ $# == 2 ] ; then
        CONTINUE_ON_MESSAGE "$1" "$2"
    fi
    exit 2
}


###############################################################################################
#
# Help function - Exit on completion
#
###############################################################################################
function BRIEFHELP {

cat << EOM

    ${BOLD}v [options] PLUGINS${NORM}

    ${BOLD}####${NORM}         ... Re-execute the command-line formed from a previous invocation, numbered ${BOLD}####${NORM}.
    ${BOLD}-d${NORM} directory ... Set a DIRECTORY NAME ${BOLD}directory${NORM}. Default is ${BOLD}NULL${NORM}.
    ${BOLD}-h${NORM}           ... Display help page.
    ${BOLD}-p${NORM} ####      ... Set a PROCESS NUMBER ${BOLD}####${NORM}. Default is ${BOLD}NULL${NORM}. 
    ${BOLD}-n${NORM} name      ... Set a APPLICATION NAME ${BOLD}name${NORM}. Default is ${BOLD}NULL${NORM}.
    ${BOLD}-q${NORM}           ... Suppress the question about whether Yes or No do you want to edit the results
    ${BOLD}-s${NORM} summary   ... Set a SUMMARY NAME ${BOLD}summary${NORM}. Default is ${BOLD}NULL${NORM}.

EOM

exit 0
}


###############################################################################################
#
# Help function - Exit on completion
#
###############################################################################################
function HELP {

  cat << EOM

${BOLD}NAME${NORM}

    ${BOLD}v${NORM} - Bash script for invoking ${BOLD}vol.py${NORM} and its plugins

${BOLD}SYNOPSIS${NORM}

    ${BOLD}v${NORM} [options]

${BOLD}DESCRIPTION${NORM}

    ${BOLD}v${NORM} creates a command-line expression that when evaluated invokes ${BOLD}vol.py${NORM} 
with a particular plugin. ${BOLD}v${NORM} documents the expression invoked and captures 
the results of this invocation. And for some plugins, ${BOLD}v${NORM} carries out additional 
post-processing to extract other interesting results. 

    ${BOLD}v${NORM} requires a local file ${BOLD}mem${NORM} to be symbolically link to the target memory 
image for processing by ${BOLD}vol.py${NORM}. After each invocation, ${BOLD}v${NORM} updates a local file ${BOLD}cnt${NORM} 
to contain the current count of invocations. Also, this script generates an MD5 
value for the memory image.  See ${BOLD}mem.md5${NORM}. And finally, this script creates a 
file ${BOLD}profiles${NORM} that contains an ordered list the recommended profiles for consideration 
by ${BOLD}vol.py${NORM}. This file is created by invoking Volatility Plugin IMAGEINFO, as in 'v imageinfo'.

${BOLD}USAGE${NORM}

    ${BOLD}v [options] PLUGINS${NORM}

    The following ${BOLD}options${NORM} are recognized.

    ${BOLD}####${NORM}         ... Re-execute the command-line formed from a previous invocation, 
                     numbered ${BOLD}####${NORM}.
                     Using this option, allows you to re-run the very same command-line option,
                     which is often the case during research.

    ${BOLD}-d${NORM} directory ... Set a DIRECTORY NAME ${BOLD}directory${NORM}. Default is ${BOLD}NULL${NORM}.
                     Setting a directory name allows ${BOLD}vol.py${NORM} to create a target directory
                     for holding assorted output files, as in the case for the plugin dumpfiles.

    ${BOLD}-h${NORM} ... Display this help page.

    ${BOLD}-n${NORM} name      ... Set a APPLICATION NAME ${BOLD}name${NORM}. Default is ${BOLD}NULL${NORM}.
                     Setting an application name allows the script ${BOLD}v${NORM} to assign
                     related results to a single named application.

    ${BOLD}-p${NORM} ####      ... Set a PROCESS NUMBER ${BOLD}####${NORM}. Default is ${BOLD}NULL${NORM}. 
                     Setting a process number allow ${BOLD}vol.py${NORM} to target a particular UNIX 
                     process for consideration.

    ${BOLD}-q${NORM}           ... Suppress the question about whether Yes or No do you want to edit the results

    ${BOLD}-s${NORM} summary   ... Set a SUMMARY NAME ${BOLD}summary${NORM}. Default is ${BOLD}NULL${NORM}.
                     Setting a summary name allows ${BOLD}vol.py${NORM} to designate a particular file name
                     for summary results.

${BOLD}EXAMPLES${NORM}

  Re-run the command-line invocation as previously used for results number ${BOLD}7${NORM}.

      ${BOLD}v 7${NORM} 

  Extract the process information for all running processes using the plugin PSLIST

      ${BOLD}v pslist ${NORM} 

  Extract the process information for a particular process ${BOLD}PID 3203${NORM} using the plugin PSLIST

      ${BOLD}v -p 3203 pslist ${NORM}

  Extract the process information for a particular process ${BOLD}PID 3203${NORM} using the plugin PSLIST, and
  organize the results using the name ${BOLD}obiwan${NORM}

      ${BOLD}v -n obiwan -p 3203 pslist ${NORM}

  Extract the results for the Volatility Plugin DUMPFILES, target process ${BOLD}PID 3203${NORM}, label your
  summary file as ${BOLD}dumpfiles${NORM}, and create a new directory ${BOLD}dumpfiles${NORM} to hold the
  results.

      ${BOLD}v -s dumpfiles -d dumpfiles -p 3203 dumpfiles${NORM}

  Ordered invocations to try.

      ${BOLD}v imageinfo${NORM}
      ${BOLD}v psinfo${NORM}
      ${BOLD}v malfind${NORM}
      ${BOLD}v netscan${NORM}
      ${BOLD}v hashdump${NORM}
      ${BOLD}v lsadump${NORM}
      ${BOLD}v dumpfiles${NORM}

EOM

  exit 1
}


main "$@"

