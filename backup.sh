## draw functions
drawHorizontalLine(){
    char="$1"
    line=""
    columnsCount="${COLUMNS:-$(tput cols)}"

    i=0
    while [ $i -ne $columnsCount ]
    do
        line="${line}$char"
        i=$(($i+1))
    done
    echo $line
}

drawHeader(){
    char=$1
    text=" ${2} "
    textCharCount=${#text}
    columnsCount="${COLUMNS:-$(tput cols)}"
    textSpaceCount=0
    tempColumnCount=0

    if [ $columnsCount -gt $textCharCount ]
    then
        tempColumnCount=$(($columnsCount - $textCharCount))
        textSpaceCount=$(($tempColumnCount / 2))
    fi

    if [ $(($tempColumnCount%2)) -ne 0 ]
    then
        text="${text}${char}"
    fi

    line=""
    doneVariable=0
    i=0
    while [ $i -ne $textSpaceCount ]
    do
        line="${line}$char"
        i=$(($i+1))

        if [ "$i" -eq "$textSpaceCount" ];
        then
            if [ "$doneVariable" -ne 1 ];
            then
                i=0
                line="${line}$text"
                doneVariable=1
            fi
        fi
    done
    if [ $doneVariable -eq 1 ]
    then
        echo $line
    else
        echo $text
    fi
}

drawBoxWithText(){
    text=" $1 "
    charCount=${#text}
    boxTop=""
    boxBottom=""

    i=0
    while [ $i -ne $charCount ]
    do
        i=$(($i+1))
        boxTop="${boxTop}▀"
        boxBottom="${boxBottom}▄"
    done

    boxTop="█${boxTop}█"
    boxBottom="█${boxBottom}█"

    echo "$boxTop"
    echo "█$text█"
    echo "$boxBottom"
}

## execute function
executeCommand(){
    echo "█ $1"
    $1
}

## global variables
currentDate=$(date +"%Y-%m-%d")
currentTime=$(date +"%T")
backupName=${currentDate}

if [ ! -z "$1" ];
then
    backupName=${currentDate}_${1}
fi;

backupDiskPath="/mnt/backup"
borgPath="$backupDiskPath/borg"
borgReposPath="$borgPath/repos"
borgSshfsMountsPath="$borgPath/sshfs-mounts"
defaultSshIdentityFile="~/.ssh/id_ed25519_storage"

## borg functions
borgBackup(){
    ## Variables
    name=$1
    pathToBackup=$2

    borgRepoPath="${borgReposPath}/$name"

    ## execute
    executeCommand "mkdir -p $borgRepoPath"

    executeCommand "borg init --encryption=none $borgRepoPath"
    executeCommand "borg create -s -p $borgRepoPath/::$name-$backupName $pathToBackup"
    executeCommand "borg prune --list --keep-daily=14 $borgRepoPath"
    executeCommand "borg list $borgRepoPath"
}

borgBackupSshf(){
    ## Variables
    name=$1
    # [user@]hostname:[directory]
    sshRemote=$2
    sshIdentityFile=$defaultSshIdentityFile

    if [ ! -z "$3" ];
    then
        sshIdentityFile=$3
    fi;

    sshfsMount="$borgSshfsMountsPath/$name"

    ## execute
    executeCommand "mkdir -p $sshfsMount"
    executeCommand "sshfs $sshRemote $sshfsMount -o IdentityFile=$sshIdentityFile"

    borgBackup $name $sshfsMount

    ## umount
    executeCommand "umount $sshfsMount"
}

###########################################################################

clear

drawHorizontalLine "█"
drawHeader "█" "BACKUP START [$(date +"%Y-%m-%d") $(date +"%T")]"
drawHeader "█" "BACKUP NAME: $backupName"
drawHorizontalLine "█"

drawHeader "█" "MOUNT"
executeCommand "mount /dev/disk/by-id/ata-QEMU_HARDDISK_QM00007 $backupDiskPath"

drawHeader "█" "FOLDER CREATION"
executeCommand "mkdir -p $borgReposPath $borgSshfsMountsPath"

##SSD BACKUP
drawHorizontalLine "█"
drawBoxWithText "SSD BACKUP"
borgBackup "ssd" "/mnt/ssd"
drawHorizontalLine "█"
##SSD BACKUP END

##DOCKER BACKUP START
drawHorizontalLine "█"
drawBoxWithText "DOCKER BACKUP"
borgBackupSshf "docker" "root@pve00-docker00:/home/docker"
drawHorizontalLine "█"
##DOCKER BACKUP END

##PUBLIC BACKUP START
drawHorizontalLine "█"
drawBoxWithText "PUBLIC BACKUP"
borgBackupSshf "public" "root@pve00-public00:/home/docker"
drawHorizontalLine "█"
##PUBLIC BACKUP END

drawHeader "█" "UMOUNT"
executeCommand "umount $backupDiskPath"

drawHorizontalLine "█"
drawHeader "█" "BACKUP DONE [$(date +"%Y-%m-%d") $(date +"%T")]"
drawHorizontalLine "█"
