# Moodle GIFT cleaner

A small Windows helper for cleaning text exports before importing questions into Moodle's **GIFT** question format. It was built for a recurring classroom workflow with Respondus exports.

## Use

1. Download `Clean-Gift.ps1` and `Clean-Gift.bat` into the same folder.
2. Drag one or more exported `.txt` files onto `Clean-Gift.bat`.
3. For each input, find a new `<name>_clean.gift` file beside the original.
4. In Moodle's question bank, choose **Import → GIFT** and preview the imported questions before using them in a quiz.

For command-line use in PowerShell:

```powershell
.\Clean-Gift.ps1 .\questions.txt
.\Clean-Gift.ps1 .\unit-*.txt
```

The batch launcher uses Windows PowerShell with a process-scoped execution-policy bypass so a downloaded, unsigned script can run. Review the two scripts before running them. The script reads and writes local text files only. It has been used successfully with Windows PowerShell 5.1 and tested with PowerShell 7.

## What it changes

- Reads the input as UTF-8, removing an initial byte order mark if present. Invalid UTF-8 fails instead of silently changing characters.
- Writes UTF-8 without a BOM and with LF line endings.
- Removes blank lines inside unescaped `{answer blocks}` and reduces extra blank lines between blocks to one. GIFT uses blank lines to separate questions.
- Leaves the original file untouched. If the cleaned filename exists, it reports an error and does not overwrite it; move or rename that file before retrying.

This is **not a GIFT parser or validator**. It does not fix missing answers, malformed syntax, or question content. Check the Moodle import preview and sample questions. Source exports with images or other external media may need a different import workflow. Never commit actual question banks or student data to a public repository.

## Test

Run the self-contained behavior test in PowerShell 7 or Windows PowerShell 5.1:

```powershell
.\tests\Test-Clean-Gift.ps1
```

The test uses temporary synthetic questions; it does not need Moodle or Respondus.

## Development

I identified the export cleanup needed for my classroom workflow and tested the behavior. The implementation was developed with AI assistance and reviewed against representative GIFT cases.

## License

Released under the [MIT License](LICENSE).
