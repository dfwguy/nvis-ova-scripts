#!/bin/bash
H=$(hostname -s); NOW=$(date +%s)
FP=$(mktemp); LOG=$(mktemp); PS=$(mktemp)
trap 'rm -f "$FP" "$LOG" "$PS"' EXIT

for f in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys*; do
  [ -r "$f" ] || continue
  o=$(echo "$f" | awk -F/ '{print ($2=="root")?"root":$3}')
  ssh-keygen -lf "$f" 2>/dev/null | awk -v o="$o" '{c="";for(i=3;i<NF;i++)c=c $i" ";print $2, o":"(c==""?"(no-comment)":c)}' >> "$FP"
done

grep -h -E "( |^)$H sshd\[[0-9]+\]: Accepted " /var/log/auth.log.1 /var/log/auth.log 2>/dev/null > "$LOG"
ps -eo pid=,etimes=,args= | awk '
  /sshd:/ && !/\[listener\]/ && !/\[accepted\]/ {
    u=""; t="no-pty"
    for(i=3;i<=NF;i++){
      if($i ~ /@pts\//){split($i,a,"@"); u=a[1]; t=a[2]; break}
      if($i ~ /^sshd:$/ && $(i+1) !~ /^\[/){u=$(i+1); gsub(/[^a-zA-Z0-9._-]/,"",u)}
    }
    if(u!="") print $1, u, t, $2
  }' | sort -k4 -n > "$PS"

printf "%-12s %-9s %-8s %-10s %-40s %s\n" USER TTY PID METHOD OWNER FINGERPRINT
awk -v host="$H" -v now="$NOW" -v fpfile="$FP" '
BEGIN{split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec",M," ");for(i in M)mn[M[i]]=i
  while((getline l < fpfile)>0){split(l,x," ");own[x[1]]=substr(l,index(l,x[2]))}}
FNR==NR{
  if($1 ~ /^[0-9][0-9][0-9][0-9]-/){
    if($2 != host) next
    d=$1; gsub(/[-T:]/," ",d); split(d,p," ")
    t=mktime(p[1]" "p[2]" "p[3]" "p[4]" "p[5]" "int(p[6]))
  } else {
    if($4 != host) next
    t=mktime(strftime("%Y")" "mn[$1]" "$2" "substr($3,1,2)" "substr($3,4,2)" "substr($3,7,2))
  }
  n++; LT[n]=t
  for(i=1;i<=NF;i++){if($i=="Accepted"){LM[n]=$(i+1);LU[n]=$(i+3)} if($i~/^SHA256:/)LF[n]=$i}
  next
}
{
  start=now-$4; m="unknown"; fp=""; bd=11
  for(i=1;i<=n;i++){d=LT[i]-start; if(d<0)d=-d; if(LU[i]==$2 && d<bd){bd=d; m=LM[i]; fp=LF[i]}}
  who=(fp=="")?"-":(fp in own?own[fp]:"UNMATCHED-KEY")
  printf "%-12s %-9s %-8s %-10s %-40s %s\n",$2,$3,$1,m,who,fp
}' "$LOG" "$PS"
