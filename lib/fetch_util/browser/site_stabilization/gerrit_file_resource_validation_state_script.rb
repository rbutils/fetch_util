# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritFileResourceValidationStateScript
        private

        def gerrit_file_resource_validation_state_script
          <<~'JS'
            const objectRecord = (value) => value && typeof value === "object" && !Array.isArray(value);
            const validTextLines = (value) => value == null ||
              (Array.isArray(value) && value.every((line) => typeof line === "string"));
            const validIntralineEdits = (value) => value == null || (Array.isArray(value) && value.every(
              (edit) => Array.isArray(edit) && edit.length === 2 && edit.every(
                (number) => Number.isInteger(number) && number >= 0
              )
            ));
            const validDiffBlock = (block) => objectRecord(block) && ["ab", "a", "b"].every(
              (field) => validTextLines(block[field])
            ) && ["edit_a", "edit_b"].every(
              (field) => validIntralineEdits(block[field])
            ) && (block.skip == null || typeof block.skip === "number" || objectRecord(block.skip));
            const validateDiff = (diff, filePath) => {
              if (diff.content != null &&
                  (!Array.isArray(diff.content) || !diff.content.every(validDiffBlock))) {
                throw new Error("invalid Gerrit diff content payload");
              }
              if (diff.diff_header != null && typeof diff.diff_header !== "string" &&
                  (!Array.isArray(diff.diff_header) ||
                    !diff.diff_header.every((line) => typeof line === "string"))) {
                throw new Error("invalid Gerrit diff header payload");
              }
              if (diff.meta_a != null && !objectRecord(diff.meta_a)) {
                throw new Error("invalid Gerrit base metadata payload");
              }
              if (diff.meta_b != null && !objectRecord(diff.meta_b)) {
                throw new Error("invalid Gerrit target metadata payload");
              }
              if (diff.meta_b && diff.meta_b.name && diff.meta_b.name !== filePath) {
                throw new Error("Gerrit API diff target identity mismatch");
              }
            };
          JS
        end
      end
    end
  end
end
