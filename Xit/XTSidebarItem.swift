import Cocoa

class XTSideBarItem: NSObject
{
  var title: String
  var displayTitle: String { return title }
  var icon: NSImage? { return nil }
  var children: [XTSideBarItem]
  var model: FileChangesModel?
  var refType: XTRefType { return .unknown }
  var expandable: Bool { return false }
  // NSObject.isSelectable is new in 10.12
  override var isSelectable: Bool { return true }
  var editable: Bool { return false }
  var current: Bool { return false }
  
  init(title: String)
  {
    self.title = title
    self.children = []
    
    super.init()
  }
  
  convenience init(title: String, model: FileChangesModel)
  {
    self.init(title: title)
    self.model = model
  }
  
  // Because children bridges as NSArray, not NSMutableArray.
  @objc(addChild:)  // Override default "addWithChild:"
  func add(child: XTSideBarItem)
  {
    children.append(child)
  }
  
  func child(matching title: String) -> XTSideBarItem?
  {
    if let child = children.first(where: { $0.title == title }) {
      return child
    }
    if let child = children.firstResult({ $0.child(matching: title) }) {
      return child
    }
    return nil
  }
  
  override var description: String { return self.title }
}


class XTSideBarGroupItem: XTSideBarItem
{
  override var isSelectable: Bool { return false }
  override var expandable: Bool { return true }
}


class XTRemotesItem: XTSideBarGroupItem
{}


class XTStagingItem: XTSideBarItem
{
  override var icon: NSImage?
  {
    return NSImage(named: .xtStagingTemplate)
  }
}


class XTStashItem: XTSideBarItem
{
  override var icon: NSImage?
  {
    return NSImage(named: .xtStashTemplate)
  }
}


class XTBranchItem: XTSideBarItem
{
  override var displayTitle: String
  { return (title as NSString).lastPathComponent }
  override var icon: NSImage?
  { return NSImage(named: .xtBranchTemplate) }
  
  var fullName: String { return title }
  
  func branchObject() -> Branch? { return nil }
}


class XTLocalBranchItem: XTBranchItem
{
  override var refType: XTRefType { return .branch }
  override var current: Bool
  {
    if let currentBranch = model!.repository.currentBranch {
      return currentBranch == title
    }
    return false
  }
  
  override func branchObject() -> Branch?
  {
    return model!.repository.localBranch(named: title)
  }

  func hasTrackingBranch() -> Bool
  {
    let branch = model!.repository.localBranch(named: title)
    
    return branch?.trackingBranchName != nil
  }
}


class XTRemoteBranchItem: XTBranchItem
{
  var remote: String
  override var refType: XTRefType { return .remoteBranch }
  
  override var fullName: String { return "\(remote)/\(title)" }
  
  init(title: String, remote: String, model: FileChangesModel)
  {
    self.remote = remote
    
    super.init(title: title)
    self.model = model
  }
  
  override func branchObject() -> Branch?
  {
    return model!.repository.remoteBranch(named: title, remote: remote)
  }
}


class XTBranchFolderItem: XTSideBarItem
{
  override var icon: NSImage? { return NSImage(named: .xtFolderTemplate) }
  override var isSelectable: Bool { return false }
  override var expandable: Bool { return true }
}


class XTRemoteItem: XTSideBarItem
{
  let remote: Remote?
  
  override var icon: NSImage?
  {
    if let urlString = remote?.urlString,
       let url = URL(string: urlString),
       let host = url.host {
      if (host == "github.com") || host.hasSuffix(".github.com") {
        return NSImage(named: .xtGitHubTemplate)
      }
    }
    return NSImage(named: .xtCloudTemplate)
  }
  
  override var expandable: Bool { return true }
  override var editable: Bool { return true }
  override var refType: XTRefType { return .remote }
  
  init(title: String, repository: XTRepository)
  {
    self.remote = repository.remote(named: title)
    
    super.init(title: title)
  }
}


class XTTagItem: XTSideBarItem
{
  let tag: Tag

  override var displayTitle: String
  { return (title as NSString).lastPathComponent }
  override var icon: NSImage?
  { return NSImage(named: .xtTagTemplate) }
  override var refType: XTRefType { return .tag }
  
  init(tag: Tag)
  {
    self.tag = tag
    
    super.init(title: tag.name)
    
    // The cast to GitTag is unfortunate but hard to get around. It doesn't seem
    // to make sense to have a repository property in the Tag protocol.
    if let commit = tag.commit,
       let xtTag = tag as? GitTag {
      self.model = CommitChanges(repository: xtTag.repository, commit: commit)
    }
  }
}


class XTSubmoduleItem: XTSideBarItem
{
  let submodule: Submodule
  override var icon: NSImage?
  { return NSImage(named: .xtSubmoduleTemplate) }
  
  init(submodule: Submodule)
  {
    self.submodule = submodule
    
    super.init(title: submodule.name)
  }
}
