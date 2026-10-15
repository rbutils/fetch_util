function MarkdownMaterializationOutput(input) {
  this.input = input;
  this.value = "";
  this.copiedThrough = 0;
}

MarkdownMaterializationOutput.prototype.flush = function(end) {
  if (end > this.copiedThrough) this.value += this.input.slice(this.copiedThrough, end);
  this.copiedThrough = end;
};

MarkdownMaterializationOutput.prototype.replace = function(start, end, replacement) {
  if (replacement === this.input.slice(start, end)) return;
  this.flush(start);
  this.value += replacement;
  this.copiedThrough = end;
};

MarkdownMaterializationOutput.prototype.finish = function() {
  this.flush(this.input.length);
  return this.value;
};
