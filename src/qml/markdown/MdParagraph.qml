import "../../code/markdownParser.js" as MarkdownParser

MdRichText {
    property var node: null
    richText: node ? MarkdownParser.renderInline(node.inline) : ""
}
