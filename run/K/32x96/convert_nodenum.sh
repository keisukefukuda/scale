#! /bin/bash -x

for file in $(ls ../1x1)
do
   f=$(basename $file)
   e=${f##*.}

   if [ ${e} = "cnf" ]; then
		sed -e "s/PRC_NUM_X=1/PRC_NUM_X=32/g" ../1x1/${f}	| \
		sed -e "s/PRC_NUM_Y=1/PRC_NUM_Y=96/g" 					> ${f}
   fi
   if [ ${e} = "sh" ]; then
		sed -e "s/1x1/32x96/g" ../1x1/${f} > ${f}
   fi
done
