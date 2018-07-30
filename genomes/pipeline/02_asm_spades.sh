#!/bin/bash
#SBATCH --nodes 1 --ntasks 16 --mem 64gb --time 24:00:00 --out logs/asm.%a.log

module load SPAdes
SAMPFILE=samples.csv
INPUT=clean_reads
ASM=asm
MEM=64
SCRATCH=/scratch/$USER
mkdir -p $ASM
mkdir -p $SCRATCH

N=${SLURM_ARRAY_TASK_ID}
CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
     CPU=$SLURM_CPUS_ON_NODE
fi

if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi

MAX=$(wc -l $SAMPFILE | awk '{print $1}')

if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPFILE"
    exit
fi

IFS=,
sed -n ${N}p $SAMPFILE | while read STRAIN LEFT RIGHT
do
  if [ ! -d $ASM/$STRAIN.SPAdes_bt ]; then
   spades.py -k 21,33,55,77,99,127  --pe1-1 $INPUT/${STRAIN}.clean_bt.fq.1.gz --pe1-2 $INPUT/${STRAIN}.clean_bt.fq.2.gz --careful -t $CPU --mem $MEM -o $ASM/$STRAIN.SPAdes_bt --tmp-dir $SCRATCH/$STRAIN
  fi
  if [ ! -d $ASM/$STRAIN.SPAdes ]; then
         spades.py -k 21,33,55,77,99,127 --pe1-1 $INPUT/${STRAIN}_1.clean.fq.gz --pe1-2 $INPUT/${STRAIN}_2.clean.fq.gz --careful -t $CPU --mem $MEM -o $ASM/$STRAIN.SPAdes --tmp-dir $SCRATCH/$STRAIN
  fi

done
