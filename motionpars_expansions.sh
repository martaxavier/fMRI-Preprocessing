#!/bin/bash

if [ $# -lt 2 ] ; then
    cat << EOF
Usage: mp_diffpow24 regparam.dat diffregparam.dat
Creates file with 24 columns; the first 6 are the motion
parameters, the next 6 are the square of the motion
parameters, the next 6 are the temporal difference of motion parameters, 
and the next 6 are the square of the differenced values.  This is useful for
accounting for 'spin history' effects, and variation not 
otherwise accounted for by motion correction.
\$Id: mp_diffpow24.sh,v 1.1 2012/10/26 11:29:29 nichols Exp $
EOF
    exit 1
fi

f=`echo $2 | sed 's/\....$//'`

cat <<EOF > /tmp/$$-mp-diffpow
{
  if (NR==1) {
    mp1=\$1;mp2=\$2;mp3=\$3;mp4=\$4;mp5=\$5;mp6=\$6;
  }
  printf("  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e    %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e    %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e  %+0.7e\n",
         \$1,\$2,\$3,\$4,\$5,\$6,
         \$1^2,\$2^2,\$3^2,\$4^2,\$5^2,\$6^2,
         \$1-mp1,\$2-mp2,\$3-mp3,\$4-mp4,\$5-mp5,\$6-mp6,
         (\$1-mp1)^2,(\$2-mp2)^2,(\$3-mp3)^2,(\$4-mp4)^2,(\$5-mp5)^2,(\$6-mp6)^2);
  mp1=\$1;mp2=\$2;mp3=\$3;mp4=\$4;mp5=\$5;mp6=\$6;
}
EOF
awk -f /tmp/$$-mp-diffpow "$1" > ${f}.dat

/bin/rm /tmp/$$-mp-diffpow 