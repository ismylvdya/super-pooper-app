// obsidian://superpooper-line?vault=…&file=…&line=…&name=…
// A link from outside Obsidian cannot name a line (its own `open` takes only a heading or a block, looked up in a cache that
// lags behind a file changed while Obsidian slept). Inside, `openFile` with `eState.line` opens the note on that line and
// highlights it, so this plugin takes the line from a link of its own and does just that.
const { MarkdownView, Notice, Plugin } = require("obsidian");

/** The line to open: the one asked for if it still holds the name, else the first that does, else the one asked for. */
function lineToOpen(lines, asked, name) {
	if (!name || (lines[asked] ?? "").includes(name)) return asked;
	const found = lines.findIndex((line) => line.includes(name));
	return found >= 0 ? found : asked;
}

module.exports = class SuperPooperOpenLine extends Plugin {
	onload() {
		this.registerObsidianProtocolHandler("superpooper-line", (params) => this.open(params));
	}

	async open({ file, line, name }) {
		const target = file ? this.app.metadataCache.getFirstLinkpathDest(file, "") : null;
		if (!target) return new Notice(`SuperPooper: no file ${file ?? ""}`);
		// From the disk, not the cache: the app may have just changed the file.
		const lines = (await this.app.vault.adapter.read(target.path)).split("\n");
		const asked = Math.min(Math.max(Number(line) || 0, 0), lines.length - 1);
		const number = lineToOpen(lines, asked, name);
		const open = this.app.workspace.getLeavesOfType("markdown").find((leaf) => leaf.view.file === target);
		const leaf = open ?? this.app.workspace.getLeaf(false);
		await leaf.openFile(target, { active: true, state: { mode: "source" }, eState: { line: number } });
		if (leaf.view instanceof MarkdownView) {
			const at = { line: number, ch: 0 };
			leaf.view.editor.setCursor(at);
			leaf.view.editor.scrollIntoView({ from: at, to: at }, true);
		}
	}
};

module.exports.lineToOpen = lineToOpen;
