#!/bin/sh
#chmod 777 ./archive.sh
#在 xy位置输出字符串并换行
function xy () {
	_R=$1
	_C=$2
	_TEXT=$3
	tput  cup $_R $_C
	echo  $_TEXT
}

function colour () {
	case $1 in
		black_green)
			echo '\033[32m';;
		black_yellow)
			echo '\033[33m';;
		black_white)
			echo  '\033[37m';;
		black_cyan)
			echo  '\033[36m';;
		black_red)
			echo  '\033[31m';;
		colour_default)
			echo  '\033[0m';;
	esac
}
#清除格式
function clearprint ()  {
	echo "\033[0m"
}

#function clear ()  {
#    echo "\033[2J"
#}

#打印系统边框
function printsqure() {
    clear
	colour black_red
	xy 3 12  "╔══════════════════════════════════════════════════════╗"
	for((x=4;x<=20;x++))
	do
		xy $x 12 "‖"
		xy $x 67 "‖"
	done
	xy 21 12 "╚══════════════════════════════════════════════════════╝"

}

#欢迎界面
function welcom() {
	printsqure
	xy 5 37 "\033[33;41m\033[1m ❀提示❀ \033[1m"
	clearprint
	colour black_red
	xy 8 33 "\033[1m命令支持类型 "
	colour black_green
    xy 10 25 "\033[1m -p:local/appstore/fir/pgy/ftp"
	xy 12 45 "© WJD"
    xy 14 25 ""
    xy 16 25 ""
    xy 18 25 ""
    xy 20 25 ""
    xy 22 25 ""
}

#进入脚本所在文件夹并生成临时文件夹

#工程绝对路径
project_path=$(cd `dirname $0`; pwd)

#打包模式 Debug/Release
development_mode=Release

#build文件夹路径
build_path=${project_path}/build

#配置文件路径
config_path=${project_path}/ipaBuildConfig
#渠道配置文件
channels=${config_path}/channels.plist

#plist文件所在路径
exportOptionsPlistPath=''

#导出.ipa文件所在路径
exportIpaPath=${build_path}/${development_mode}

#工程名 去配置文件替换成自己的工程名
project_name=$(/usr/libexec/PlistBuddy -c "print project_name" "${channels}")

#scheme名 将XXX替换成自己的sheme名
scheme_name=$(/usr/libexec/PlistBuddy -c "print scheme_name" "${channels}")

#账号密码配置
account=''
password=''


#开始执行脚本
welcom

if [ $# -lt 1 ]; then
    echo "命令行需要参数;"
    exit 1
fi

#发布类型
publishType=''

while getopts ":p:bcd" opt
do
    case $opt in
        p ) publishType=$OPTARG;;
        ? ) echo "参数非法"
        exit 1;;
    esac
done

#根据发布类型读取配置
if [ ! -n "$publishType" ];then
    echo "-p:参数非法"
    exit 0
else
    development_mode=$(/usr/libexec/PlistBuddy -c "print ${publishType}:development_mode" "${channels}")
    exportOptionsPlistName=$(/usr/libexec/PlistBuddy -c "print ${publishType}:exportOptionsPlistName" "${channels}")
    exportOptionsPlistPath=${config_path}/${exportOptionsPlistName}

    account=$(/usr/libexec/PlistBuddy -c "print ${publishType}:account" "${channels}")
    password=$(/usr/libexec/PlistBuddy -c "print ${publishType}:password" "${channels}")

    if [ ! -n "$development_mode" ];then
        echo "-p:参数非法"
        exit 0
    else
        echo "读取的配置  development_mode:"${development_mode} "exportOptionsPlistName:" ${exportOptionsPlistName}
    fi

fi

echo '打包类型:${publishType}'

echo '-----------------------------'
echo '|        正在清理工程		  |'
echo '-----------------------------'

#创建ipa-build文件夹
if [ -d ${build_path} ];then
    rm -rf ${build_path}
fi
xcodebuild clean -configuration ${development_mode} -quiet  || exit
mkdir ${build_path}

echo '-----------------------------'
echo '|         清理完成	  |'
echo '-----------------------------'
echo ''

echo '-----------------------------'
echo '| 正在编译工程:【'${development_mode}'】|'
echo '-----------------------------'

echo 'xcodebuild archive -workspace ' ${project_name}'.xcworkspace -scheme '${scheme_name}' -configuration '${development_mode}' -archivePath '${build_path}/${project_name}'.xcarchive'
xcodebuild archive -workspace ${project_name}.xcworkspace -scheme ${scheme_name} -configuration ${development_mode} -archivePath ${build_path}/${project_name}.xcarchive -quiet  || exit

echo '-----------------------------'
echo '|		 编译完成		  |'
echo '-----------------------------'
echo ''

echo '-----------------------------'
echo '| 	开始ipa打包	    | '
echo '-----------------------------'
xcodebuild -exportArchive -archivePath ${build_path}/${project_name}.xcarchive \
-configuration ${development_mode} \
-exportPath ${exportIpaPath} \
-exportOptionsPlist ${exportOptionsPlistPath} \
-quiet || exit

if [ -e $exportIpaPath/$scheme_name.ipa ]; then
echo '-----------------------------'
echo '| 	ipa包已导出	  |'
echo '-----------------------------'
open $exportIpaPath
else
echo '-----------------------------'
echo '| 	ipa包导出失败	  |'
echo '-----------------------------'
fi
echo '-----------------------------'
echo '| 	打包ipa完成  	  |'
echo '-----------------------------'
echo ''

if [ $publishType == 'local' ];then
    exit 0
fi

echo '-----------------------------'
echo '| 	开始发布ipa包 	 |'
echo '-----------------------------'

if [ $publishType == 'appstore' ];then

#验证并上传到App Store
	altoolPath="/Applications/Xcode.app/Contents/Applications/Application Loader.app/Contents/Frameworks/ITunesSoftwareService.framework/Versions/A/Support/altool"
"$altoolPath" --validate-app -f ${exportIpaPath}/${scheme_name}.ipa -u ${account} -p ${password} -t ios --output-format xml
"$altoolPath" --upload-app -f ${exportIpaPath}/${scheme_name}.ipa -u ${account} -p ${password} -t ios --output-format xml
elif [ $publishType == 'pgy' ];then
# 上传IPA到蒲公英
	echo '-----------------------------'
	echo '| 	上传IPA到蒲公英   |'
	echo '-----------------------------'
	curl -F "file=@"${exportIpaPath}"/"${scheme_name}.ipa \
	-F "uKey=${account}" \
	-F "_api_key=${password}" \
	https://www.pgyer.com/apiv2/app/upload
#	open https://www.pgyer.com
elif [ $publishType == 'fir' ];then
#上传到Fir 
	echo '-----------------------------'
	echo '| 	上传到fir   |'
	echo '-----------------------------'

	fir login -T ${account}
	fir publish $exportIpaPath/$scheme_name.ipa
#	open http://fir.im

fi

exit 0
