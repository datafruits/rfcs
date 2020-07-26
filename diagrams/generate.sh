CHANGED_DIAGRAMS=""
for diagram in $(git status --porcelain | grep mmd | cut -d' ' -f3)
do
  OUTFILE=$(echo $diagram | cut -d'.' -f1).png
  yarn mmdc -i $diagram -o $OUTFILE -t neutral
  CHANGED_DIAGRAMS="$CHANGED_DIAGRAMS\n$OUTFILE"
  git add OUTFILE
done

if [-z $CHANGED_DIAGRAMS]
then
  exit 0
fi

echo "Created or overwrote the following files:"
printf "$CHANGED_DIAGRAMS\n\n"
