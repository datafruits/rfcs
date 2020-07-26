for diagram in diagrams/*.mmd
do
  OUTFILE=$(echo $diagram | cut -d'.' -f1).png
  yarn mmdc -i $diagram -o $OUTFILE -t neutral
done