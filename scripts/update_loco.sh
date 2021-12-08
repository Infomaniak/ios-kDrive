#!/bin/bash

#localise.biz configuations
EXPORT_URL=https://localise.biz/api/export/archive/
EXPORT_FORMAT=
API_KEY=
TAG=ios
FALLBACK=en
PLURALS=false

#default download directory
DOWNLOAD_DIR=/tmp
DOWNLOAD_FILE_NAME=tmp_localise_export

#execution options
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
OUTPUT_PATH="$(dirname $SCRIPT_DIR)/kDrive/Resources"
NAME='Localizable'
FORCE_COPY=false
MAPS=('en=en' 'fr=fr' 'de=de' 'it=it' 'es=es')

#colors for echo
RED='\033[0;31m'
GREEN='\033[0;32m'
GRAY='\033[0;37m'
YELLOW='\033[1;33m'
PINK='\033[1;35m'
NC='\033[0m'

#CLASS VAR
total_exported=0

####FUNCTIONS####

# $0=exported langCode
# $1=target project langCode
function tryCopyLangFilesiOS {
  #validate the parameters
  exportedLang=$1
  targetLang=$2
  if [ -z $exportedLang ] || [ -z $targetLang ]; then
    echo -e "${RED}Error! Unknown exported lang code or target lang code when trying to copy files"
    exit 1
  fi

  cd $UNZIP_PATH; cd *
  exportedStringsFile=
  if [ $PLURALS == true ]; then
    exportedStringsFile=$exportedLang".lproj/Localizable.stringsdict"
  else
    toConvertStringsFile=$exportedLang".lproj/Localizable.strings"
    exportedStringsFile=$exportedLang".lproj/Fixed.strings"
    iconv -f UTF-16BE -t UTF8 < $toConvertStringsFile > $exportedStringsFile
  fi

  #check if exported lang file exists and OUTPUT_PATH is set
  if [ ! -z $OUTPUT_PATH ]; then
    #then ensure the target lang dir exists and create it otherwise
    targetLangDir=$OUTPUT_PATH"/"$targetLang".lproj"
    targetLangFile=
    if [ $PLURALS == true ]; then
      targetLangFile=$targetLangDir"/"$NAME".stringsdict"
    else
      targetLangFile=$targetLangDir"/"$NAME".strings"
    fi

    if [ ! -d $targetLangDir ]; then
      mkdir $targetLangDir
      echo -e "No ${targetLang}.lproj folder, created a new one."
    fi
    cp $exportedStringsFile $targetLangFile
    echo -e "${PINK}${targetLang} updated from localise.biz!\n"
  fi
}

function tryCopyLangFilesAndroid {
  #validate the parameters
  exportedLang=$1
  targetLang=$2
  if [ -z $exportedLang ] || [ -z $targetLang ]; then
    echo -e "${RED}Error! Unknown exported lang code or target lang code when trying to copy files"
    exit 1
  fi

  # cd $UNZIP_PATH
  cd $UNZIP_PATH
  cd $(find . -type d -name "*xml-archive")
  cd "res"

  exportedStringsFile=$exportedLang"/strings.xml"
  #check if exported lang file exists and OUTPUT_PATH is set
  if [ ! -z $OUTPUT_PATH ]; then
    #then ensure the target lang dir exists and create it otherwise
    targetLangDir=$OUTPUT_PATH"/"$targetLang
    targetLangFile=

    if [ $PLURALS == true ]; then
      targetLangFile=$targetLangDir"/plurals.xml"
    else
      targetLangFile=$targetLangDir"/strings.xml"
    fi

    echo -e "Lang file: $targetLangFile"

    if [ ! -d $targetLangDir ]; then
      mkdir $targetLangDir
      echo -e "No ${targetLang} folder, created a new one."
    fi

    cp $exportedStringsFile $targetLangFile
    echo -e "${PINK}${targetLang} updated from localise.biz!\n"
    let "total_exported++"
  fi
}

function cleanUp {
  echo -e "${YELLOW}** Cleaning up...\n${NC}"
  cd /tmp
  rm -rf $UNZIP_PATH
  rm -f $DOWNLOAD_FILE_NAME
}


#check platform
PLATFORM=

case $1 in
  [iI][oO][sS])
    PLATFORM="ios"
    shift
    ;;
  android)
    PLATFORM="android"
    shift
    ;;
    *)
      echo -e "${RED}Please specific which platform to export, ${GRAY}ios ${RED}or ${GRAY}android${RED}?${NC}"
      exit 1
    ;;
esac

#check options
while getopts ":-:" opt; do
  case $opt in
    -)
      case "${OPTARG}" in
        key)
          val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          API_KEY=$val
          ;;
        tag)
          val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          TAG=$val
          ;;
        fallback)
          val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          FALLBACK=$val
          ;;
        plurals)
          val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          PLURALS=true
          ;;
        output)
          val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          echo -e "Output Path set to ${GRAY}${val}${NC}"
          OUTPUT_PATH=$val
          ;;
        name)
          val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          echo -e "Name set to ${GRAY}${val}${NC}"
          NAME=$val
          ;;
        force)
          FORCE_COPY=true
          echo "FORCE_COPY"
          ;;
        map)
          val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
          MAPS+=($val)
          ;;
        *)
          echo -e "${RED}${OPTARG} is not an valid options"
          exit 1
          ;;
      esac
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
    :)
      echo "option: -$OPTARG requires an argument" >&2
      ;;
  esac
done

#check for nessesory options

if [ -z $OUTPUT_PATH ]; then
  echo -e "${RED}No output path set\n\nTerminated.${NC}"
  exit 1
fi

if [ -z $API_KEY ]; then
  echo -e "${RED}No API key set\n\nTerminated.${NC}"
  exit 1
fi

#check for additional options

if [ ! -z $TAG ]; then
  echo -e "${GREEN}TAG set: ${TAG}"
fi

if [ ! -z $FALLBACK ]; then
  echo -e "${GREEN}FALLBACK set: ${FALLBACK}"
fi

#check if tmp directory exists
echo -e "${YELLOW}** Checking tmp directory...${NC}"

if [ ! -d $DOWNLOAD_DIR ]; then
  echo -e "${RED}No /tmp directory available\n\nTerminated.${NC}"
else
  echo -e "${GREEN}/tmp OK${NC}"
fi

#make up the export api

if [[ $PLATFORM == "ios" ]]; then
  if [ $PLURALS == true ]; then
    EXPORT_FORMAT="stringsdict.zip"
    echo -e "${YELLOW}** Going to Export iOS PLURALS...${NC}"
  else
    EXPORT_FORMAT="strings.zip"
    echo -e "${YELLOW}** Going to Export iOS...${NC}"
  fi
elif [[ $PLATFORM == "android" ]]; then
  EXPORT_FORMAT="xml.zip"
  if [ $PLURALS == true ]; then
    echo -e "${YELLOW}** Going to Export Android XML PLURALS...${NC}"
  else
    echo -e "${YELLOW}** Going to Android XML...${NC}"
  fi
fi

EXPORT_URL_FINAL="${EXPORT_URL}${EXPORT_FORMAT}?key=${API_KEY}&order=id"

if [ ! -z $TAG ]; then
  EXPORT_URL_FINAL="${EXPORT_URL_FINAL}&filter=${TAG}"
fi

if [ ! -z $FALLBACK ]; then
  EXPORT_URL_FINAL="${EXPORT_URL_FINAL}&fallback=${FALLBACK}"
fi

DOWNLOAD_PATH_FINAL="${DOWNLOAD_DIR}/${DOWNLOAD_FILE_NAME}.zip"
echo -e "Export URL: ${GRAY}$EXPORT_URL_FINAL${NC}"
echo -e "Saving to: ${GRAY}$DOWNLOAD_PATH_FINAL${NC}"

#download, check, and unzip
curl "$EXPORT_URL_FINAL" "--output" "${DOWNLOAD_PATH_FINAL}"
if [ -e $DOWNLOAD_PATH_FINAL ]; then
  echo -e "${GREEN}Download SUCCESS${NC}"
else
  echo -e "${RED}Download FAILED\n\nTerminated.${NC}"
fi

echo -e "${YELLOW}** Unzipping export...${NC}"
UNZIP_PATH="$DOWNLOAD_DIR/$DOWNLOAD_FILE_NAME"
unzip -qo "$DOWNLOAD_PATH_FINAL" -d $UNZIP_PATH

if [ ! -d $UNZIP_PATH ]; then
  echo -e "${RED}Export unzip FAILED\n\nTerminated.${NC}"
else
  echo -e "${GREEN}Export Unzipped.${NC}"
fi

#check unzipped content for ios
echo -e "${YELLOW}** Inspecting exported files...\n${NC}"
cd $UNZIP_PATH

for i in "${MAPS[@]}"; do
  IFS='=' read -ra mapKV <<< "$i"
  if [ ! -z ${mapKV[0]} ] || [ ! -z ${mapKV[0]} ]; then
    echo -e "${YELLOW}** Copying files from ${mapKV[0]} to ${mapKV[1]}...${NC}"
    if [[ $PLATFORM == "ios" ]]; then
      tryCopyLangFilesiOS ${mapKV[0]} ${mapKV[1]}
    elif [[ $PLATFORM == "android" ]]; then
      tryCopyLangFilesAndroid ${mapKV[0]} ${mapKV[1]}
    fi
  fi
done

#cleanUp
cleanUp

if [ $total_exported > 0 ]; then
  echo -e "${GREEN}Export FINISH!! Total exported languages: ${total_exported}"
fi

exit 0
