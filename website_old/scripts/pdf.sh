FILES="./src/docs/*/*.md"
for f in $FILES
do
    pandoc --from=markdown $f \
        --template="src/docs/cs127_handout_template.tex" \
        --lua-filter="./scripts/filter.lua" \
        --highlight-style pygments \
        --listings \
        -o static/gen/$(basename $f | cut -f 1 -d '.').pdf
done
