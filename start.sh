#!/bin/bash

source packer.config

echo "==========输出配置信息=========="
echo $INPUT_APK_PATH
echo $KEYSTORE_PATH
echo $KEYSTORE_PASSWORD
echo $KEYSTORE_ALIAS
echo $KEYSTORE_ALIAS_PASSWORD
echo $CHANNELS_FILE_PATH

output_dir="build/output"
building_dir="build/packing"

rm -rf build
mkdir -p $output_dir
mkdir -p $building_dir

ZIPALIGN_FILE_PATH="${output_dir}/zipalign.apk"
APKSIGNER_FILE_PATH="${building_dir}/zipalign_signed.apk"

echo "==========开始zip对齐=========="
#zip对齐
./src/zipalign -v -p 4 $INPUT_APK_PATH $ZIPALIGN_FILE_PATH
echo "==========开始v2签名=========="
#v2签名
./src/apksigner sign  --ks $KEYSTORE_PATH --ks-key-alias $KEYSTORE_ALIAS --ks-pass pass:"$KEYSTORE_PASSWORD" --key-pass pass:"$KEYSTORE_ALIAS_PASSWORD"  --out $APKSIGNER_FILE_PATH  $ZIPALIGN_FILE_PATH
echo "==========开始验证签名=========="
#验证签名是否已添加
./src/apksigner verify -v $APKSIGNER_FILE_PATH
echo "==========开始添加渠道信息=========="
#添加渠道包
java -jar ./src/packer-ng-2.0.0.jar generate --channels=@$CHANNELS_FILE_PATH --output=$output_dir $APKSIGNER_FILE_PATH
echo "==========开始验证渠道是否已添加=========="
#循环遍历验证所有渠道包是否添加正确
for file in ${output_dir}/*; do
    echo "文件路径：$file"
    #验证渠道是否已添加
    java -jar ./src/packer-ng-2.0.0.jar verify $file
done