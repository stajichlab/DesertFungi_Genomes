#!/bin/bash
#SBATCH --nodes 1 --ntasks 2 --mem 8G -J trimReads --out logs/trim.%a.log

module load trimmomatic
SAMPLES=samples.csv
CPU=$SLURM_CPUS_ON_NODE
if [ ! $CPU ]; then
    CPU=1
fi

N=${SLURM_ARRAY_TASK_ID}

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "Need an array id or cmdline val for the job"
        exit
    fi
fi
ADT=$(dirname $TRIMMOMATIC)"/adapters/TruSeq3-PE.fa"
echo $ADAPTOR
IFS=,
sed -n ${N}p $SAMPLES | while read STRAIN LEFT RIGHT
do
    echo "$STRAIN $LEFT $RIGHT"
    base=$(basename $LEFT _1.fq.gz)
    dir=$(dirname $LEFT)
    if [ ! -f $dir/${base}_1.trim.fq.gz ]; then
       java -jar $TRIMMOMATIC PE -phred33 $LEFT $RIGHT \
            $dir/${base}_1.trim.fq.gz $dir/${base}_1.unpaired_trim.fq.gz \
            $dir/${base}_2.trim.fq.gz $dir/${base}_2.unpaired_trim.fq.gz \
            ILLUMINACLIP:$ADT:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:75
    fi
done
