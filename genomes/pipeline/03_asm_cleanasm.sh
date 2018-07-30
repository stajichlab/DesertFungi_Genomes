#!/bin/bash
#SBATCH -p batch --time 2-0:00:00 --ntasks 2 --nodes 1 --mem 8G --out logs/clean.%a.log
module load ncbi-blast/2.7.1+
module load python/3
INDIR=asm
OUTDIR=asm_clean
MINLEN=500
DB=/srv/projects/db/UniVec/UniVec
CLEANVEC=`pwd`"../autovectorscreen/scripts/clean_vect_blastn.py"

CPU=1
if [ $SLURM_CPUS_ON_NODE ]; then
    CPU=$SLURM_CPUS_ON_NODE
fi
SAMPFILE=samples.csv
N=${SLURM_ARRAY_TASK_ID}
if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
       echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=`wc -l $SAMPFILE | awk '{print $1}'`

if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPFILE"
    exit
fi
IFS=,
sed -n ${N}p $SAMPFILE | while read STRAIN LEFT RIGHT
do
#currently species column also contains strain info so no need to concatenate
 if [ ! -f $OUTDIR/$STRAIN.SPAdes_clean.fasta ]; then
    mkdir -p $STRAIN.$$
    pushd $STRAIN.$$
    # if > XX we should probably remove
    perl $SCRIPTS/filter_db_by_seqlen.pl -l $MINLEN ../$INDIR/$STRAIN/scaffolds.fasta > $STRAIN.trunc.fasta

    blastn -task blastn -reward 1 -penalty -5 -gapopen 3 -gapextend 3 -dust yes -soft_masking true -evalue 700 -searchsp 1750000000000 \
        -db $DB -outfmt 6 -num_threads $CPU -query $STRAIN.trunc.fasta -out $STRAIN.vecscreen.blastn

#    COUNT=$(grep -c '>' $name.trunc.fasta)
#    echo "COUNT is $COUNT"
#    if [ "$COUNT" -gt "3000" ]; then
#      mv $name.trunc.fasta ../$OUTDIR/$name.SPAdes_clean.fasta 
#    else
#        funannotate clean -i $name.trunc.fasta -o ../$OUTDIR/$name.SPAdes_clean.fasta
#        rm $name.trunc.fasta
#    fi
#    popd
#    rmdir $name.$$
 else 
     echo "Already processed and created $OUTDIR/$name.SPAdes_clean.fasta"
 fi
done
