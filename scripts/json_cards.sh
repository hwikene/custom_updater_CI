#!/bin/bash
#Author: Joakim Sørensen @ludeeus


git config --global user.name "$GH_USER" || exit 1
git config --global user.email "$GH_MAIL" || exit 1

mkdir /publish
cd /publish || exit 1
git init
git remote add origin https://$GH_USER:$GH_API@github.com/custom-cards/information.git || exit 1
git fetch --all && git reset --hard origin/master

jsondata=$(curl -u "$GH_USER:$GH_API" -sSL https://api.github.com/orgs/custom-cards/repos | jq -r .)
jsonfile='/publish/repos.json'

if [ -f $jsonfile ];then
  rm $jsonfile
fi

echo "{" >> $jsonfile
for row in $(echo "${jsondata}" | jq -r 'sort_by(.name)[] | @base64'); do
  _jq() {
  echo ${row} | base64 --decode | jq -r ${1}
  }
  name=$(_jq '.name')
  archived=$(_jq '.archived')
  echo "Generating json for $name"
  updated_at=$(_jq '.updated_at')
  base_url='https://raw.githubusercontent.com/custom-cards/'
  url=$base_url$name'/master/'
    live=$(curl -sSL $url'VERSION')
    test=$(echo $live | grep "404: Not Found")
    if [[ -z "$test" ]];then
      version=$(curl -sSL $url'VERSION')
      remote_location=$base_url$name'/master/'$name'.js'
      changelog=$(curl -sSL $url'changelog.md')
      test=$(echo $changelog | grep "404: Not Found")
      if [[ ! -z "$test" ]];then
        changelog='https://github.com/custom-cards/'$name'/releases/latest'
      else
        changelog='https://github.com/custom-cards/'$name'/blob/master/changelog.md'
      fi
      visitrepo='https://github.com/custom-cards/'$name
    fi
  if [[ "$name" == "information" ]]; then
    echo Nothing to see here
  elif [[ "$name" == "" ]]; then
    echo Nothing to see here
  elif [[ "$archived" == "true" ]]; then
    echo "Nothing to see here..."
  else
    cat >> $jsonfile <<EOF
    "$name": {
      "updated_at": "${updated_at::10}",
      "version": "$version",
      "remote_location": "$remote_location",
      "visit_repo": "$visitrepo",
      "changelog": "$changelog"
    },
EOF
  fi
done


jsondata=$(curl -u "$GH_USER:$GH_API" -sSL https://api.github.com/users/thomasloven/repos | jq -r .)
for row in $(echo "${jsondata}" | jq -r 'sort_by(.name)[] | @base64'); do
  _jq() {
  echo ${row} | base64 --decode | jq -r ${1}
  }
  name=$(_jq '.name')
  archived=$(_jq '.archived')
  if [[ $name == lovelace-* ]]; then
    echo "Generating json for $name"
    updated_at=$(_jq '.updated_at')
    base_url='https://raw.githubusercontent.com/thomasloven/'
    url=$base_url$name'/master/'
    versiondata=$(curl -u "$GH_USER:$GH_API" -sSL https://api.github.com/repos/thomasloven/$name/commits | jq -r . | jq .[0].sha)
    version=${versiondata:1:6}
    live=$(curl -sSL $remote_location)
    test=$(echo $live | grep "404: Not Found")
    if [[ ! -z "$test" ]];then
      shortname=${name:9}
    else:
      shortname=$name
    fi
    remote_location=$base_url$name'/master/'$shortname'.js'
    changelog=$(curl -sSL $url'changelog.md')
    test=$(echo $changelog | grep "404: Not Found")
    if [[ ! -z "$test" ]];then
      changelog='https://github.com/thomasloven/'$name'/releases/latest'
    else
      changelog='https://github.com/thomasloven/'$name'/blob/master/changelog.md'
    fi
    visitrepo='https://github.com/thomasloven/'$name
  cat >> $jsonfile <<EOF
  "$shortname": {
    "updated_at": "${updated_at::10}",
    "version": "$version",
    "remote_location": "$remote_location",
    "visit_repo": "$visitrepo",
    "changelog": "$visitrepo"
  },
EOF
  fi
done


mkdir /ciotlosm
cd /ciotlosm || exit 1
git init
git remote add origin https://github.com/ciotlosm/custom-lovelace.git
git fetch --all && git reset --hard origin/master
baseurl='https://raw.githubusercontent.com/ciotlosm/custom-lovelace/master/'
for D in `find . -maxdepth 1 -type d`;do
    DIR=$(echo $D | awk -F'/' '{print $2}')
    if [[ "$DIR" == ".git" ]]; then
      echo "nothing to see here"
    elif [[ "$DIR" == "." ]]; then
      echo "nothing to see here"
    elif [[ "$DIR" == "" ]]; then
      echo "nothing to see here"
    else
      version=$(cat './'${D}'/VERSION')
      download=$baseurl$DIR'/'$DIR'.js'
      changelog='https://github.com/ciotlosm/custom-lovelace/tree/master/'$DIR'/changelog.md'
      visitrepo='https://github.com/ciotlosm/custom-lovelace/tree/master/'$DIR
      test=$(echo '"'$DIR'"')
      if ! grep -q $test $jsonfile; then
        echo adding $DIR
        cat >> $jsonfile <<EOF
        "$DIR": {
          "updated_at": "Unknown",
          "version": "$version",
          "remote_location": "$download",
          "visit_repo": "$visitrepo",
          "changelog": "$changelog"
        },
EOF
      else
        echo skipping $DIR
      fi
    fi
done


cd /publish || exit 1
sed -i '$ s/.$//' $jsonfile
echo "}" >> $jsonfile
cat $jsonfile
count=$(wc -l $jsonfile | awk -F' ' '{print $1}')
if [[ $count -gt 10 ]]; then
  git add .
  git commit -m "Update repos.json"
  git push -u origin master
else
  exit 0
fi