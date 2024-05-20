ObjC.import("AppKit")

const argv = $.NSProcessInfo.processInfo.arguments.js.map(arg => arg.js)
const pboard = $.NSPasteboard.generalPasteboard
const pathData = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(
  argv.slice(1), $.NSPropertyListXMLFormat_v1_0, 0, undefined)
  
pboard.declareTypesOwner($[$.NSFilenamesPboardType], undefined)
pboard.setDataForType(pathData, $.NSFilenamesPboardType)
