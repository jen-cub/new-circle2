#!/usr/bin/env bash
set -euo pipefail

if [ -z "$1" ]; then
  echo "Version tag is missing"
  exit 1
fi

VERSION="$1"

now="$(date +'%Y-%m-%d')"
volunteer_memo=""

changelog="\n<h2>${VERSION} - ${now}</h2>\n\n"

JIRA_API_QUERY="https://jira.greenpeace.org/rest/api/latest/search?jql=project%20%3D%20PLANET%20AND%20fixVersion%20%3D%20${VERSION}&fields=summary,issuetype,customfield_13100,customfield_12100,issuetype,assignee"

jira_json=$(curl -s "$JIRA_API_QUERY")
retval=$?
if [ "$retval" -ne 0 ]; then
  echo "Failed to query JIRA for issue"
  exit 1
fi

echo "$jira_json" | jq --raw-output '.issues []  | .key ' > /tmp/$$.keys
echo "$jira_json" | jq --raw-output '.issues []  | .fields .summary ' > /tmp/$$.summaries
echo "$jira_json" | jq --raw-output '.issues []  | .fields .customfield_12100 .value ' > /tmp/$$.tracks
echo "$jira_json" | jq --raw-output '.issues []  | .fields .issuetype .name ' > /tmp/$$.issuetypes
echo "$jira_json" | jq --raw-output '.issues []  | .fields .assignee .name ' > /tmp/$$.assignees

keys=()
i=0
while read -r line
do
  keys[i]=$line
  i=$((i + 1))
done < /tmp/$$.keys

summaries=()
i=0
while read -r line
do
  summaries[i]=$line
  i=$((i + 1))
done < /tmp/$$.summaries

issuetypes=()
i=0
while read -r line
do
  issuetypes[i]=$line
  i=$((i + 1))
done < /tmp/$$.issuetypes

tracks=()
i=0
while read -r line
do
  tracks[i]=$line
  i=$((i + 1))
done < /tmp/$$.tracks

assignees=()
i=0
while read -r line
do
  assignees[i]=$line
  i=$((i + 1))
done < /tmp/$$.assignees

total=${#keys[*]}

if [ "$total" -ne 0 ]; then
  features="<h3>🔧 Features</h3>\n\n<ul>\n"
  bugs="<h3>🐞 Bug Fixes</h3>\n\n<ul>\n"
  infra="<h3>👷 Infrastructure</h3>\n\n<ul>\n"
  features_md="### Features\n\n"
  bugs_md="\n### Bug Fixes\n\n"
  infra_md="\n### Infrastructure\n\n"

  for (( i=0; i<=$(( total -1 )); i++ ))
  do
    key=$(echo "${keys[$i]}" | xargs )
    summary="${summaries[$i]}"
    assignee="${assignees[$i]}"
    track="${tracks[$i]}"
    issuetype="${issuetypes[$i]}"


    volunteer_star=""
    if [ "$assignee" == "volunteer" ]; then
      volunteer_star=" <font size='1'>⭐</font>"
      volunteer_memo="<font size='1'>⭐ Contributed by a volunteer</font>"
    fi

    ticket="<li><a href='https://jira.greenpeace.org/browse/${key}'>${key}</a> - ${summary}${volunteer_star}</li>\n"
    ticket_md="- [${key}](https://jira.greenpeace.org/browse/${key}) - ${summary}\n"

    if [ "$track" == "Infra" ]; then
      infra="$infra$ticket"
      infra_md="$infra_md$ticket_md"
    elif [ "$issuetype" == "Task" ]; then
      features="$features$ticket"
      features_md="$features_md$ticket_md"
    else
      bugs="$bugs$ticket"
      bugs_md="$bugs_md$ticket_md"
    fi

  done

  features="$features</ul>\n"
  bugs="$bugs</ul>\n"
  infra="$infra</ul>\n"
fi

md="## ${VERSION} - ${now}\n\n"

if [ ${#features} -gt 100 ]; then
  changelog="$changelog$features\n"
  md="$md$features_md"
fi

if [ ${#bugs} -gt 100 ]; then
  changelog="$changelog$bugs\n"
  md="$md$bugs_md"
fi

if [ ${#infra} -gt 100 ]; then
  changelog="$changelog$infra\n"
  md="$md$infra_md"
fi

changelog="$changelog\n$volunteer_memo\n"
md="\n$md"

# Send Changelog to email
MSG_SUBJECT="[Release] v$VERSION 🤖"
MSG_BODY="Hi everyone,<br><br> A new Planet 4 release is being deployed today. Below is the full list of changes.<br>$changelog<br><a href='https://support.greenpeace.org/planet4/tech/changelog'><font size='1'>Release History</font></a><br><br>The P4 Bot 🤖"
EMAIL_TO="$RELEASE_EMAIL_TO"
EMAIL_FROM="$RELEASE_EMAIL_FROM"
json=$(jq -n \
  --arg EMAIL_TO "$EMAIL_TO" \
  --arg EMAIL_FROM "$EMAIL_FROM" \
  --arg MSG_SUBJECT "$MSG_SUBJECT" \
  --arg MSG_BODY "$MSG_BODY" \
'{
  "personalizations": [
    {
      "to": [
        {
          "email": $EMAIL_TO
        }
      ]
    }
  ],
  "from": {"email": $EMAIL_FROM},
  "subject": $MSG_SUBJECT,
  "content": [
    {
      "type": "text/html",
      "value": $MSG_BODY
    }
  ]
}')
curl --request POST \
  --url https://api.sendgrid.com/v3/mail/send \
  --header "Authorization: Bearer $SENDGRID_API_KEY" \
  --header 'Content-Type: application/json' \
  --data "${json}"

# Commit Chagelog to Gitbook
git config user.email "circleci-bot@greenpeace.org"
git config user.name "CircleCI Bot"
git config push.default simple
commit_message=":robot: Changelog $VERSION"
git clone -b master git@github.com:greenpeace/planet4-docs.git
cd planet4-docs/docs/tech/changelog/
first=$(head -n 8 README.md)
last=$(tail -n +9 README.md)
echo "$first" > README.md
echo -e "$md" >> README.md
echo "$last" >> README.md
git add README.md
git commit -m "$commit_message"
git push origin master