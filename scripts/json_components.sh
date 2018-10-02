#!/bin/bash
#Author: Joakim Sørensen @ludeeus


git config --global user.name "$GH_USER" || exit 1
git config --global user.email "$GH_MAIL" || exit 1

mkdir /publish
cd /publish || exit 1
git init
git remote add origin https://$GH_USER:$GH_API@github.com/custom-components/information.git || exit 1
git fetch --all && git reset --hard origin/master

jsondata=$(curl -u "$GH_USER:$GH_API" -sSL https://api.github.com/orgs/custom-components/repos?per_page=1000 | jq -r .)
jsonfile='./repos.json'

if [ -f $jsonfile ];then
  rm $jsonfile
fi

echo "{" >> $jsonfile
echo $jsondata
for row in $(echo "${jsondata}" | jq -r 'sort_by(.name)[] | @base64'); do
  _jq() {
  echo ${row} | base64 --decode | jq -r ${1}
  }
  name=$(_jq '.name')
  archived=$(_jq '.archived')
  if [[ "$name" == "information" ]]; then
    echo "Nothing to see here..."
  elif [[ "$archived" == "true" ]]; then
    echo "Nothing to see here..."
  else
    echo "Generating json for $name"
    updated_at=$(_jq '.updated_at')
    #get version:
    base_url='https://raw.githubusercontent.com/custom-components/'
    if [[ "$name" == *"."*  ]]; then
      sub_dir=$(echo $name | awk -F'.' '{print $1}')'/'
      file=$(echo $name | awk -F'.' '{print $2}')
    else
      sub_dir=''
      file=$name
    fi
      url=$base_url$name'/master/custom_components/'$sub_dir$file'.py'
      live=$(curl -sSL $url)
      test=$(echo $live | grep "404: Not Found")
      if [[ -z "$test" ]];then
        version=$(echo $live | grep "__version__ " | head -n 1 | awk -F"'" '{print $2}')
        if [[ -z "$test" ]];then
          version=$(echo $live | grep "VERSION " | head -n 1 | awk -F"'" '{print $2}')
        fi
        local_location='/custom_components/'$sub_dir$file'.py'
        remote_location=$url
        visitrepo='https://github.com/custom-components/'$name
        changelog=$visitrepo'/releases/latest'
      else
        url=$base_url$name'/master/custom_components/'$sub_dir$file'/__init__.py'
        live=$(curl -sSL $url)
        version=$(echo $live | grep "__version__ " | head -n 1 | awk -F"'" '{print $2}')
        local_location='/custom_components/'$sub_dir$file'/__init__.py'
        remote_location=$url
        visitrepo='https://github.com/custom-components/'$name
        changelog=$visitrepo'/releases/latest'
      fi
    cat >> $jsonfile <<EOF
    "$name": {
      "updated_at": "${updated_at::10}",
      "version": "$version",
      "local_location": "$local_location",
      "remote_location": "$remote_location",
      "visit_repo": "$visitrepo",
      "changelog": "$changelog"
    },
EOF
  fi
done
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