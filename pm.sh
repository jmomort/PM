#! /bin/bash

# Copyright 2011 Jonathan Mortensen, Bastien Rance
# GPLv3

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.



#set -x

#set default proj_dir to a var
PM_DIR=~/.pm/
#project_list
PM_LIST=$PM_DIR"projects"
#global config names
PM_ENTER=$PM_DIR"pm.conf"
PM_UPDATE=$PM_DIR"pm_update.conf"
PM_EXIT=$PM_DIR"pm_exit.conf"
#local config names
CONF=".pm"
CONF_U=$CONF"_update"
CONF_E=$CONF"_exit"
#location of ONDIR config
ONDIR=~/.ondirrc


print_usage() 
{
cat << END_OF_USAGE_MESSAGE

-i		installs pm into home directory (~)
	
-c [LOG]  	adds current directory to pm and creates LOG
		asks for project name (for switching), title, and description  
		future commits will be saved to LOG
	
-u  		commits the last command to LOG of current project
		includes date and time as comment
		appends relative path to project root
	
-m [MSG]	adds quoted MSG to LOG as comment
	
-o		prints LOG to stdout
	
-d [PROJ]	deletes PROJ from pm (removes local config & lines from ondirrc)
	
-h		prints usage

END_OF_USAGE_MESSAGE
}


create_pm()
{
  	LOG=$1
	# setup the local config file
	#create local .pm configs in cur_dir and 
	touch "$CONF" "$CONF_E" "$CONF_U"
#append log file location and curr_proj dir to enter config
cat >> $CONF << THE_END_OF_THE_MESSAGE_1	
export CURR_PROJ="$PWD"
export PM_LOG_FILE="$PWD"/"$LOG"
export last_dir="$PWD"
THE_END_OF_THE_MESSAGE_1

# add project to OnDir
#append enter and exit scripts to ONDIR
cat >> $ONDIR << THE_END_OF_THE_MESSAGE_2
enter $PWD
	source "$PM_ENTER"
	source "$PWD"/"$CONF"
leave $PWD
	source "$PM_EXIT"
	source "$PWD"/"$CONF_E"
THE_END_OF_THE_MESSAGE_2
}

initial_input()
{
		LOG=$1
		echo "Give a name to the project -- should be short, one word, will be used to switch projects"
		read name
		echo "Give a title"
		read title
		echo "Provide a brief description"
		read desc
		#add the project name to the project list for quick project switching
		echo -e "$name""\t""$PWD" >> "$PM_LIST"
		
		#finally save info to the log file
cat >> $LOG << THE_END_OF_THE_MESSAGE_3	
Title: $title
Description: $desc
THE_END_OF_THE_MESSAGE_3

}

install_pm ()
{
	mkdir "$PM_DIR"
	#create_default_configs
	touch "$PM_ENTER"
	touch "$PM_UPDATE"
	touch "$PM_EXIT"

	#make the proj_list
	touch "$PM_LIST"

#Add the basic update script to the pm global update
cat >> "$PM_UPDATE" << "THE_END_OF_THE_MESSAGE_4"
	echo "# "$(date) >> "$CURR_PROJ"/"$PM_LOG_FILE"
    LAST_CMD=`more ${HOME}/.bash_history | tail -1`
    cwd=$PWD
    RELATIVE_PATH=${cwd//$CURR_PROJ/""}
    RELATIVE_PATH=${RELATIVE_PATH:1}
    if [ ${#RELATIVE_PATH} -gt 0 ] ; then
      current_string=""
      for elt in $LAST_CMD ; do
	  last_char=${elt#${elt%?}}
            if [ $last_char == "\\" ] ; then
	      e=`echo $elt | sed 's/.$//'`
              current_string=$current_string" "$e
  	    else
	      o=$current_string" "$elt
  	      o=`echo $o | sed 's/^ +//'`
 	      if [ -e "$o" ] ; then
                # replace space by backslash space
		o=`echo $o | sed 's/ /\\\\ /g'`
		relative_path_cmd=$relative_path_cmd" "$RELATIVE_PATH"/"$o
	      else
		relative_path_cmd=$relative_path_cmd" "$o
	      fi
	      current_string=""
	  fi
      done
      echo $relative_path_cmd >> "$CURR_PROJ"/"$PM_LOG_FILE"
  else
    echo $LAST_CMD >> "$CURR_PROJ"/"$PM_LOG_FILE"
  fi   
THE_END_OF_THE_MESSAGE_4

# add save the last dir on exit to the main exit config
cat >> "$PM_EXIT" << "THE_END_OF_THE_MESSAGE_5"
DIR=${OLDPWD//\//\\\/}
sed -c -i "s/\(last_dir *= *\).*/\1\"$DIR\"/" "$CURR_PROJ"/.pm
THE_END_OF_THE_MESSAGE_5
	
	#set proj_dir to env variable
	#remind the user of necessary remaining steps
	echo "For pm to work, add the following PM_DIR variable to you .bashrc:"
	echo "export PM_DIR=""$PM_DIR"
	echo "additionally, add the pm function in the INSTALL file to your .bashrc file"
	echo "and either restart or source your .bashrc"
	
	exit 0
}

# creation of configuration file/project
create_proj()
{
	##this check does not seem to work correctly (wanted to check if the parent directory is under PM (what do we do in this situation...)
	## checked by see if CURR_PROJ is set...this might not be a good idea.
    if [ ! -f "$PWD"/"$CONF" ] ; then
	create_pm $OPTARG
	  	# Request a message with Title, Description??
	initial_input $OPTARG 
    else
	echo "A configuration file already exists in this directory"
    fi
}

# write the last command line and date in the log file
update()
{
	source "$PM_UPDATE"
	source "$CURR_PROJ"/"$CONF_U"
}
#
#if [ ! -f $PM_LIST ] ; then
#	echo "no projects set"
#fi

#check the project config file
#if [ ! -f $CURR_PROJ"/"$CONF ]; then
  # file in the current directory
#	echo "Missing configuration file, create one"
#	exit 1
#else
	
while getopts "m:uc:od:ih" opt; do
  case $opt in
    m) # write message in the log file
	  echo "#msg: "$OPTARG >> "$CURR_PROJ"/"$PM_LOG_FILE"
      ;;
    u)  # write the last command line and date in the log file
	  update
      ;;
    c) # creation of configuration file/project
	  create_proj
      ;;
    o) #print the log (if you forget the name....)
	  cat "$PM_LOG_FILE"
      ;;
    d) #delete a project
    	#after confirming remove the config file and the row from proj_list
		#find the config file using proj_list
		$PROJ_REM=$(grep $OPTARG $PM_LIST | cut -f 2)
		cd $PROJ_REM
		rm $CONF $CONF_U $CONF_E
		#remove row in proj_list
		sed -i '/^'$OPTARG'/d' $PM_LIST
		#remove rows in ondirrc
		t=$(mktemp)
		more $ONDIR | grep -n -w enter | grep -A1 $PROJ_REM > $t
		line1=`more .t | sed '2d' | cut -d ":" -f1`
		line2=`more .t | sed '1d' | cut -d ":" -f1`
		let line2=$line2-1
		sed '$line1,$line2""d' $ONDIR
		rm $t
		#Note envi var will need to be reset
		echo "Reset your shell to reset any changed environment variables"
    	;;
    i) #install
		#check if PM_DIR is made, check if ondir is installed, check if a config file is set
    	## change -n to -v for 4.2 bash
		if [ ! -n "$PM_DIR" -o ! -e "$PM_DIR" ]; then
			install_pm
		else
			echo "already installed"
		fi
		;;
	h)
		print_usage
		;;
    \?)
      echo "Invalid option: -"$OPTARG >&2
      ;;
  esac
done


#4 things
#when you enter a project -- OnDIR
#when you exec a command -- BashVARS through change in onDIR
###when you commit/add directly (script execs lines with a uniq char in the config files)##
#when you exit onDIR
#enter these in global and a local config

#Need to make an INSTALL and README, upload to Google code (also contact ondir)
#for deleting a project, remove the local configs, remove the line from the projects list and use the proj path in the projects lists
# as a search in the ondirrc, once you find the enter command for that exact path, remove everthing after that until you encounter another "enter"
#sed '|project_dir|,|enter|d'
