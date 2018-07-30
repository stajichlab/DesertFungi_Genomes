#!/bin/bash
#SBATCH --nodes 1 --ntasks 16 --mem 24G -J trimReads --out logs/trim.%a.log

module load trimmomatic
module load samtools/1.8
module load bwa/0.7.17
module load bowtie2
module load bedtools
module load BBMap
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

TMPDIR=tmp
mkdir -p $TMPDIR
if [ ! -f $TMPDIR/vectors.fa ]; then
    pushd $TMPDIR
    wget -c --tries=0 --read-timeout=20 ftp://ftp.ncbi.nlm.nih.gov/genomes/Viruses/enterobacteria_phage_phix174_sensu_lato_uid14015/NC_001422.fna
    wget -c  --tries=0 --read-timeout=20 ftp://ftp.ncbi.nlm.nih.gov/pub/UniVec/UniVec
    # common lab contaminant
    curl 'https://www.ebi.ac.uk/ena/data/view/CP011305.1%26display%3Dfasta' > CP011305.fna
    curl 'https://www.ebi.ac.uk/ena/data/view/CP011306.1%26display%3Dfasta' > CP011306.fna
    curl 'https://www.ebi.ac.uk/ena/data/view/CP015612.1%26display%3Dfasta' > CP015612.fna
    curl 'https://www.ebi.ac.uk/ena/data/view/CP016756.1%26display%3Dfasta' > CP016756.fna
    curl 'https://www.ebi.ac.uk/ena/data/view/CP022053.1%26display%3Dfasta' > CP022053.fna
    cat *.fna UniVec > vectors.fa
    bwa index -p vectors vectors.fa
    bowtie2-build --threads $CPU vectors.fa vectors
    popd
fi
dir=clean_reads
ADT=$(dirname $TRIMMOMATIC)"/adapters/TruSeq3-PE.fa"
echo $ADAPTOR
IFS=,
sed -n ${N}p $SAMPLES | while read STRAIN LEFT RIGHT
do
    echo "$STRAIN $LEFT $RIGHT"
    base=$(basename $LEFT _1.fq.gz)
    if [ ! -f $dir/${base}_1.trim.fq.gz ]; then
       java -jar $TRIMMOMATIC PE -phred33 $LEFT $RIGHT \
            $dir/${base}_1.trim.fq.gz $dir/${base}_1.unpaired_trim.fq.gz \
            $dir/${base}_2.trim.fq.gz $dir/${base}_2.unpaired_trim.fq.gz \
            ILLUMINACLIP:$ADT:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:75
    fi
    if [ ! -f $dir/${base}.clean_bt.1.fq.gz ]; then
      bowtie2 -x $TMPDIR/vectors -p $CPU -q -1 $dir/${base}_1.trim.fq.gz -2 $dir/${base}_2.trim.fq.gz --very-sensitive --un-conc-gz $dir/${base}.clean_bt.fq.gz > /dev/null 2>&1
    fi
    if [ ! -f $dir/${base}_1.clean.fq ]; then

#       if [ ! -f $TMPDIR/${base}.vectors_unmapped_bbmap_sort.bam ]; then
#            if [ ! -f $TMPDIR/${base}.vectors_bbmap.sam ]; then
#             bbmap.sh ref=$TMPDIR/vectors.fa in1=$dir/${base}_1.trim.fq.gz in2=$dir/${base}_2.trim.fq.gz out=$TMPDIR/${base}.vectors_bbmap.sam nodisk
#            fi
#            samtools view --threads $CPU -b  $TMPDIR/${base}.vectors_bbmap.sam >  $TMPDIR/${base}.vectors_bbmap.bam
#            samtools view --threads $CPU -b -f 12 $TMPDIR/${base}.vectors_bbmap.bam > $TMPDIR/${base}.vectors_unmapped_bbmap.bam
#            samtools sort --threads $CPU -n $TMPDIR/${base}.vectors_unmapped_bbmap.bam > $TMPDIR/${base}.vectors_unmapped_bbmap_sort.bam
#            unlink $TMPDIR/${base}.vectors_bbmap.sam
#        fi
       if [ ! -f $TMPDIR/${base}.vectors_unmapped_sort.bam ]; then
            bwa mem -t $CPU $TMPDIR/vectors $dir/${base}_1.trim.fq.gz $dir/${base}_2.trim.fq.gz > $TMPDIR/${base}.vectors_map.sam
            samtools view --threads $CPU -b  $TMPDIR/${base}.vectors_map.sam >  $TMPDIR/${base}.vectors_map.bam
            samtools view --threads $CPU -b -f 12 $TMPDIR/${base}.vectors_map.bam > $TMPDIR/${base}.vectors_unmapped.bam
            samtools sort --threads $CPU -n $TMPDIR/${base}.vectors_unmapped.bam > $TMPDIR/${base}.vectors_unmapped_sort.bam
            unlink $TMPDIR/${base}.vectors_map.sam
        fi   
#        if [  ! -f $dir/${base}_1.clean_bbmap.fq.gz ]; then
#            bedtools bamtofastq -i $TMPDIR/${base}.vectors_unmapped_bbmap_sort.bam -fq $dir/${base}_1.clean_bbmap.fq -fq2 $dir/${base}_2.clean_bbmap.fq
#            pigz $dir/${base}_1.clean_bbmap.fq $dir/${base}_2.clean_bbmap.fq
#        fi
        if [ ! -f $dir/${base}_1.clean.fq.gz ]; then
            bedtools bamtofastq -i $TMPDIR/${base}.vectors_unmapped_sort.bam -fq $dir/${base}_1.clean.fq -fq2 $dir/${base}_2.clean.fq
            pigz $dir/${base}_1.clean.fq $dir/${base}_2.clean.fq
        fi
    fi
done
