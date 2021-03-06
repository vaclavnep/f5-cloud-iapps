PROJECT_ID="$1"
REPO="$2"
BRANCH="$3"
FILE="$4"
BUILD_ID="$5"

RELEASE=^release-.*
HOTFIX=^hf-.*

if [ `uname` == 'Darwin' ]; then
    SED_ARGS="-E -i .bak"
else
    SED_ARGS="-r -i"
fi

# grab the file name from the last part of the relative file path
FILE_NAME=${FILE##*/}
echo FILE_NAME "$FILE_NAME"
DOWNLOAD_LOCATION=/tmp/"$FILE_NAME"

if [[ -n "BUILD_ID" && "$BRANCH" =~ $RELEASE || "$BRANCH" =~ $HOTFIX ]]; then
    echo Using build artifact
    UNZIP_DIR=/tmp/f5-cloud-dist
    URL="${CI_BASE_URL}/${PROJECT_ID}/builds/${BUILD_ID}/artifacts"
    echo URL "$URL"
    curl -s --insecure -o ${DOWNLOAD_LOCATION}.zip -H "PRIVATE-TOKEN: $API_TOKEN" "$URL"
    echo Unzipping build to ${UNZIP_DIR}
    unzip -d ${UNZIP_DIR} ${DOWNLOAD_LOCATION}.zip
    mv ${UNZIP_DIR}/dist/* /tmp
    rm -rf ${UNZIP_DIR}
else
    echo Using dist directory
    URL=${CM_BASE_URL}/${REPO}/raw/${BRANCH}/${FILE}
    echo URL "$URL"
    curl -s --insecure -o "$DOWNLOAD_LOCATION" "$URL"
fi

pushd "$(dirname "$0")"

# grab the file name from the last part of the relative file path
FILE_NAME=${FILE##*/}
echo FILE_NAME "$FILE_NAME"

# download the file and calculate hash
curl -s --insecure -o "$DOWNLOAD_LOCATION" "$URL"

OLD_HASH=$(grep "$FILE_NAME" ../f5-service-discovery/f5.service_discovery.tmpl | grep 'set hashes' | awk '{print $3}')
NEW_HASH=$(openssl dgst -sha512 "$DOWNLOAD_LOCATION" | cut -d ' ' -f 2)
echo OLD_HASH "$OLD_HASH"
echo NEW_HASH "$NEW_HASH"

if [[ -z "$NEW_HASH" ]]; then
    echo 'No hash generated'
    exit 1
fi

if [[ "$OLD_HASH" == "$NEW_HASH" ]]; then
    echo 'No change in hash'
    exit 0
fi

# update the hash
sed $SED_ARGS "s/set hashes\($FILE_NAME\) .*/set hashes\($FILE_NAME\) $NEW_HASH/" ../f5-service-discovery/f5.service_discovery.tmpl

# strip off the signature
sed $SED_ARGS "/tmpl-signature/d" ../f5-service-discovery/f5.service_discovery.tmpl

#cleanup
rm -f DOWNLOAD_LOCATION
rm -f ../f5-service-discovery/f5.service_discovery.tmpl.bak

popd
