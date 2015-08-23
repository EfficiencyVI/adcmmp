#!/bin/bash

function shutdown {
    # Cleanup
    [ -d $TMP ] && rm -fr $TMP
    exit 0
}

if [[ $EUID -eq 0 ]]; then
    echo >&2 "This program should never be run using sudo or as the root user!\n"
    exit 1
fi

warning=0
VERSION=1
BACKTITLE="Alternative Downloader for Curse Minecraft Modpacks V0.1 (Currently only Ubuntu/Debian)"

# Check for needed programs
if [ "$(which jq)" = "" ] || [ "$(which recode)" = "" ] || [ "$(which dialog)" = "" ]; then
    echo >&2 "You are missing one or more of the following programs:"
    echo >&2 "- jq (Processing json data on the command line)"
    echo >&2 "- recode (Translate html encoded text back to ascii)"
    echo >&2 "- dialog (Show some fancy GUI on the command line)\n"

    while true; do
        read -p "Do you wish to install the missing programs?" yn
        case $yn in
            [Yy]* ) sudo apt-get -y install jq recode dialog; break;; # TODO: More Distributions
            [Nn]* ) exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [ -r /tmp/curse_downloader_config ]; then
  echo "Reading config...." >&2
  . /tmp/curse_downloader_config
fi

echo $warning

if [ "$warning" -lt "$VERSION" ] ; then
    dialog --backtitle "$BACKTITLE" --title "What is this?" --yesno "\nWelcome! This is my alternative installer for Minecraft mod packs hosted on curse.com. Unfortunately the curse launcher is only available on Windows at the moment. Providing modpacks for Linux is a pain for the modpack authors and the users. This program is intended to make this a bit easier for you.\n\nThis program was written by EfficiencyVI. It is not related, maintained or affiliated with curse.com. It is also in an early development. That means expect it to not work, show odd errors, destroy your data or kill your hamster.\n\nI put a lot of effort in ensuring that this program works as best as possible but I will take no resposibility or guarantee that everything goes well no matter if you use it correct or not. Only if you are okay to be a test bunny click yes to proceed!" 30 70

    # Read response from dialog
    dialog=$?
    case $dialog in
        1|255) exit 1;;
        *) echo "warning=$VERSION" >> /tmp/curse_downloader_config;;
    esac
fi

# Start a new installation
# Create temp file for menus
TMP=/tmp/curse.$$
INPUT=$TMP/input
OUTPUT=$TMP/output

mkdir $TMP > /dev/null 2>&1
rm -fr $TMP/* > /dev/null 2>&1
mkdir $TMP/modpack > /dev/null 2>&1

if [ ! -d $HOME/.MultiMC/ ] ; then
    dialog --backtitle "$BACKTITLE" --title "About MultiMC" --yesno "\nMultiMC is an alternative launcher for Minecraft. It gives you a lot of options to manage multiple instances of Minecraft like Modpacks, Vanilla customization and so on. It is the easiest way to make custom modpacks running on your computer.\n\nIf you click yes this program will try to download the correct version for your plattform. The software is installed in your home directory in the \".MultiMC\" folder.\n\nIf you want to know more about MultiMC visit the official website and support the authors. https://multimc.org" 30 70
    
    # Read response from dialog
    dialog=$?
    case $dialog in
        0) 
            if [ ! -d ~/.MultiMC/ ]; then
                if [ $(getconf LONG_BIT) = "64" ]; then
                    URL="https://files.multimc.org/downloads/mmc-stable-lin64.tar.gz"
                else
                    URL="https://files.multimc.org/downloads/mmc-stable-lin32.tar.gz"
                fi
                wget -O $TMP/MultiMC.tar.gz "$URL" 2>&1 | \
                stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | \
                dialog --backtitle "$BACKTITLE" --title "MultiMC setup" --gauge "Downloading MultiMC" 10 100
                
                tar -xzf $TMP/MultiMC.tar.gz -C $TMP
                mkdir $HOME/.MultiMC
                cp -r $TMP/MultiMC/* $HOME/.MultiMC/
            fi
            ;;
       *)
            # TODO: Alternative!
            shutdown
    esac
fi

while true; do
    dialog --backtitle "$BACKTITLE" --title "Please choose one of the following modpacks!" --menu "\nSome popular packs are already preinstalled in this program. Just use the up and down keys to select the modpack you want. If your desired modpack is not in the list choose other for more options.\n\n" 30 70 8 \
    233818 "The Purple Garden: A Garden of Glass Modpack" \
    233579 "Forgecraft - The Modpack" \
    225550 "Agrarian Skies 2" \
    227425 "Magic Farms 3: Harvest" \
    999999 "other" 2>"${INPUT}"
    menuitem=$(<"${INPUT}")

    if [ "$menuitem" = "" ]; then
        shutdown
    fi

    if [ "$menuitem" = "999999" ]; then
        dialog  --backtitle "$BACKTITLE" --title "Custom mod pack" --inputbox "\nPlease add id of the mod pack on curse, e. g. http://www.curse.com/modpacks/minecraft/229330-crash-landing-1-6-4 would be 229330. Just type in the number." 30 70 2>"${INPUT}"
        menuitem=$(<"${INPUT}")
    fi
    menuitem=$menuitem | sed 's/[^0-9]*//g'

    URL="http://minecraft.curseforge.com/modpacks/$menuitem-modpack/files/latest"
    TITLE=$(wget --quiet -O - "http://minecraft.curseforge.com/modpacks/$menuitem-modpack" | sed -n -e 's!.*<title>Overview - \(.*\) - Modpacks.*!\1!p' | recode html..ascii)

    if [ ! "$TITLE" = "" ]; then
        break
    fi
done

wget -O $TMP/tmp.zip "$URL" 2>&1 | \
 stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | \
 dialog --backtitle "$BACKTITLE" --title "Downloading Modpack" --gauge "\n Downloading \"$TITLE\"" 10 100

# TODO MD5 verification

echo "0" | dialog --backtitle "$BACKTITLE" --title "Preparing files" --gauge "Please wait" 10 100
unzip $TMP/tmp.zip -d $TMP/modpack > /dev/null 2>&1
echo "100" | dialog --backtitle "$BACKTITLE" --title "Preparing files" --gauge "Please wait" 10 100

FILE=$TMP/modpack/manifest.json
TO=$(cat $FILE | jq '.files | length')
MP=$(cat $FILE | jq '.name' | sed 's/^.\(.*\).$/\1/')
VER=$(cat $FILE | jq '.version' | sed 's/^.\(.*\).$/\1/')
AUTHOR=$(cat $FILE | jq '.author' | sed 's/^.\(.*\).$/\1/')
MVER=$(cat $FILE | jq '.minecraft.version' | sed 's/^.\(.*\).$/\1/')
FVER=$(cat $FILE | jq '.minecraft.modLoaders[0].id' | sed 's/^.forge-\(.*\).$/\1/')
f=0

mkdir -p "$HOME/.MultiMC/instances/$MP ($VER)" > /dev/null 2>&1
cat >"$HOME/.MultiMC/instances/$MP ($VER)/instance.cfg" <<EOL
InstanceType=OneSix
name=${MP} (${VER})
IntendedVersion=${MVER}
MaxMemAlloc=2048
MinMemAlloc=2048
PermGen=256
OverrideMemory=true
EOL
echo <<< EOL

while true; do
    if [ -f "$HOME/.MultiMC/instances/$MP ($VER)/patches/net.minecraftforge.json" ] && [ $(cat "$HOME/.MultiMC/instances/$MP ($VER)/patches/net.minecraftforge.json" | grep $FVER | wc -l) -gt "0" ]; then
        break
    else
        dialog --backtitle "$BACKTITLE" --title "How to set up MultiMC!" --msgbox "\n!!! IMPORTANT !!! Please read carefully !!!\n\nMultiMC was downloaded to your system and this program will try to configure everything for you as best as possible for you. But there is one manual step on the way. You will have to do the following:\n\nAfter you pressed on \"OK\" MultiMC will open automatically. There is already an instance \"$MP ($VER)\" added for you. Right click the icon in the overview and click on \"Edit instance\".\n\nClick on \"Install Forge\" on the right of the window. After that select version $FVER!\n\nIt is important that you select the right version because the installation will not proceed unless the correct forge version is detected. After you selected the right version close MultiMC and the installation can finish.\n\nIf you get back to this screen after you closed the program something went wrong. Most likely you picked the wrong version." 30 70
        $HOME/.MultiMC/MultiMC
    fi
done

echo "0" | dialog --backtitle "$BACKTITLE" --title "Generating Modlist" --gauge "\nUnfortunately Curse does not provide the Mod names in the configuration file. To make the list usable for you all the names are now downloaded from the curse page. Depending on the number of mods this may take a while." 10 100
modnames+=( "" )
for i in $(seq $TO)
do
        echo $((100/$TO*$i)) | dialog --backtitle "$BACKTITLE" --title "Generating Modlist" --gauge "\nUnfortunately Curse does not provide the mod names in the configuration file. To make the list usable for you all the names are now downloaded from the curse page. This may take a while depending on the number of mods." 10 100
        REQ=$(cat $FILE | jq '.files['$i-1'].required')
        PID=$(cat $FILE | jq '.files['$i-1'].projectID')
        TITLE=$(wget --quiet -O - http://minecraft.curseforge.com/mc-mods/$PID | sed -n -e 's!.*<title>Overview - \(.*\) - Mods.*!\1!p' | recode html..ascii)

        if [ "$REQ" = "null" ] || [ $REQ = "true" ]; then
            modlist+=( "$i" "$TITLE" "on" )
        else
            modlist+=( "$i" "$TITLE" "off" )
        fi
        modnames+=( "$TITLE" )
done

dialog --backtitle "$BACKTITLE" --title "Welcome!" --checklist "\nThese are all mods that have to be downloaded to make this modpack working for you. To select or deselect single mods use your up and down keys and press space. All mods with an asterisk in front will be downloaded. Optional mods are not selected by default. Mostly they are more useful for server owners or have only decorative purposes. Refer to the modpack description or authors for more information.\n\n" 30 70 20 "${modlist[@]}" 2>$OUTPUT

if [ "$(cat $OUTPUT)" = "" ]; then
    shutdown
fi

for n in $(cat $OUTPUT)
do
    PID=$(cat $FILE | jq '.files['$n-1'].projectID')
    FID=$(cat $FILE | jq '.files['$n-1'].fileID')
    TITLE=${modnames[$n]}
    URL='http://minecraft.curseforge.com/mc-mods/'$PID'-mod/files/'$FID'/download'
    VERIFY='http://minecraft.curseforge.com/mc-mods/'$PID'-mod/files/'$FID

    wget -P $TMP/modpack/overrides/mods/ --trust-server-names "$URL" 2>&1 | \
    stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | \
    dialog --backtitle "$BACKTITLE" --title "Downloading Mods" --gauge "\nDownloading \"$TITLE\"" 10 100

    # TODO MD5 verification
done

# Copy all the files into MultiMC
cp -r $TMP/modpack/overrides/* "$HOME/.MultiMC/instances/$MP ($VER)/minecraft/" > /dev/null 2>&1

dialog --backtitle "$BACKTITLE" --title "Welcome!" --msgbox "\nEverything should be ready for you now. After you click \"OK\" MultiMC will launch. Double click the entry for your modpack and MultiMC will provide all the missing files you need and start your game. If this is the first time using MultiMC you will also have to add your userdata the launcher.\n\nTo start MultiMC in the future call \"~/.MultiMC/MultiMC\" from the console or add a shortcut in your start menu. You don't need this program anymore!\n\nHave fun with your modpack and thank you for using this installer. If you have any suggestions or improvements tell me about it or contribute in the package! https://github.com/EfficiencyVI/adcmmp or efficiencyvi6@gmail.com" 30 70

$HOME/.MultiMC/MultiMC &
shutdown
