#!/bin/bash
H=$(hostname -s); NOW=$(date +%s)

# fingerprint -> "user:comment" from all authorized_keys
: > /tmp/fpmap
for f in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys*; do
  [ -r "$f" ] || continue
  o=$(echo "$f" | awk -F/ '{print ($2=="root")?"root":$3}')
  ssh-keygen -lf "$f" 2>/dev/null | awk -v o="$o" '{c="";for(i=3;i<NF;i++)c=c $i" ";print $2, o":"(c==""?"(no-comment)":c)}' >> /tmp/fpmap
done

awk -v host="$H" -v now="$NOW" '
BEGIN{split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec",M," ");for(i in M)mn[M[i]]=i
  while((getline l < "/tmp/fpmap")>0){split(l,x," ");own[x[1]]=substr(l,index(l,x[2]))}}
FNR==NR{
  if($0 !~ /: Accepted / || $4 != host) next
  n++; LT[n]=mktime(strftime("%Y")" "mn[$1]" "$2" "substr($3,1,2)" "substr($3,4,2)" "substr($3,7,2))
  for(i=1;i<=NF;i++){if($i=="Accepted"){LM[n]=$(i+1);LU[n]=$(i+3)} if($i~/^SHA256:/)LF[n]=$i}
  next
}
{
  start=now-$4; m="unknown"; fp=""; bd=11
  for(i=1;i<=n;i++){d=LT[i]-start; if(d<0)d=-d; if(LU[i]==$2 && d<bd){bd=d; m=LM[i]; fp=LF[i]}}
  who = (fp=="") ? "-" : (fp in own ? own[fp] : "UNMATCHED-KEY")
  printf "%-12s %-9s %-8s %-10s %-20s %s\n",$2,$3,$1,m,who,fp
}' <(grep " $H sshd" /var/log/auth.log) \
   <(ps -eo pid=,etimes=,args= | awk '{for(i=3;i<=NF;i++) if($i~/@pts\//){split($i,u,"@");print $1,u[1],u[2],$2;break}}')
