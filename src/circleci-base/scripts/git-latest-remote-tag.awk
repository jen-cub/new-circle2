#!/usr/bin/awk -f
BEGIN {
  if (ARGC != 2) {
    print "git-latest-remote-tag.awk https://github.com/stedolan/jq"
    exit
  }
  FS = "[ /^]+"
  while ("git ls-remote " ARGV[1] "| sort -Vk2" | getline) {
    if (!sha)
      sha = substr($0, 1, 7)
    if ($2~/tags/)
      tag = $3
  }
  while ("curl -s " ARGV[1] "/releases/tag/" tag | getline)
    if ($3 ~ "commits")
      com = $2
  printf com ? "%s-%s-g%s\n" : "%s\n", tag, com, sha
}
