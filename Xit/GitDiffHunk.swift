import Foundation

public protocol DiffHunk
{
  var oldStart: Int32 { get }
  var oldLines: Int32 { get }
  var newStart: Int32 { get }
  var newLines: Int32 { get }
  
  func enumerateLines(_ callback: (DiffLine) -> Void)
  func canApply(to lines: [String]) -> Bool
}

extension DiffHunk
{
  /// Applies just this hunk to the target text.
  /// - parameter text: The target text.
  /// - parameter reversed: True if the target text is the "new" text and the
  /// patch should be reverse-applied.
  /// - returns: The modified hunk of text, or nil if the patch does not match
  /// or if an error occurs.
  func applied(to text: String, reversed: Bool) -> String?
  {
    var lines = text.components(separatedBy: .newlines)
    guard Int(oldStart - 1 + oldLines) <= lines.count
    else { return nil }
    
    var oldText = [String]()
    var newText = [String]()
    
    enumerateLines {
      (line) in
      let content = line.text
      
      switch line.type {
        case .context:
          oldText.append(content)
          newText.append(content)
        case .addition:
          newText.append(content)
        case .deletion:
          oldText.append(content)
        default:
          break
      }
    }
    
    let targetLines = reversed ? newText : oldText
    let replacementLines = reversed ? oldText : newText
    
    let targetLineStart = Int(reversed ? newStart : oldStart) - 1
    let targetLineCount = Int(reversed ? self.newLines : self.oldLines)
    let replaceRange = targetLineStart..<(targetLineStart+targetLineCount)
    
    if targetLines != Array(lines[replaceRange]) {
      // Patch doesn't match
      return nil
    }
    lines.replaceSubrange(replaceRange, with: replacementLines)
    
    return lines.joined(separator: text.lineEndingStyle.string)
  }
  
  /// Returns true if the hunk can be applied to the given text.
  /// - parameter lines: The target text. This is an array of strings rather
  /// than the raw text to more efficiently query multiple hunks on one file.
  public func canApply(to lines: [String]) -> Bool
  {
    guard (oldLines == 0) || (oldStart - 1 + oldLines <= lines.count)
    else { return false }
    
    var oldText = [String]()
    
    enumerateLines {
      (line) in
      switch line.type {
        case .context, .deletion:
          oldText.append(line.text)
        default:
          break
      }
    }
    
    // oldStart and oldLines are 0 if the old file is empty
    let targetLineStart = max(Int(oldStart) - 1, 0)
    let targetLineCount = Int(self.oldLines)
    let replaceRange = targetLineStart..<(targetLineStart+targetLineCount)
    
    return oldText == Array(lines[replaceRange])
  }
}

// Some useful functions require both the patch and the hunk, so git_diff_hunk
// can't always be used on its own.
struct GitDiffHunk: DiffHunk
{
  let hunk: git_diff_hunk
  let index: Int
  let patch: GitPatch
  
  public var oldStart: Int32 { return hunk.old_start }
  public var oldLines: Int32 { return hunk.old_lines }
  public var newStart: Int32 { return hunk.new_start }
  public var newLines: Int32 { return hunk.new_lines }
  
  public func enumerateLines(_ callback: (DiffLine) -> Void)
  {
    let lineCount = git_patch_num_lines_in_hunk(patch.patch, index)
    
    for lineIndex in 0..<lineCount {
      let line = UnsafeMutablePointer<UnsafePointer<git_diff_line>?>
                 .allocate(capacity: 1)
      let result = git_patch_get_line_in_hunk(line, patch.patch, index,
                                              Int(lineIndex))
      guard result == 0,
            let finalLine = line.pointee?.pointee
      else { continue }
      
      callback(finalLine)
    }
  }
}
