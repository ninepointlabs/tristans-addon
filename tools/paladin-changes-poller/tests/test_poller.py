"""Offline tests for the change poller (fixtures only; no network)."""
import importlib.util
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("poller", HERE.parent / "poller.py")
poller = importlib.util.module_from_spec(spec)
spec.loader.exec_module(poller)

RSS = """<?xml version="1.0"?><rss version="2.0"><channel>
<item><title>WoW Forever Hotfixes - November 10</title><link>https://example.test/a</link>
<pubDate>Mon, 10 Nov 2026 18:00:00 +0000</pubDate>
<description>&lt;p&gt;Paladin: Holy Strike damage increased by 5%.&lt;/p&gt;&lt;p&gt;Fixed a crash.&lt;/p&gt;</description></item>
<item><title>WoW Forever: Warrior tuning</title><link>https://example.test/b</link>
<pubDate>Mon, 10 Nov 2026 18:00:00 +0000</pubDate><description>Mortal Strike changes.</description></item>
<item><title>Retail: Paladin changes in Midnight</title><link>https://example.test/c</link>
<pubDate>Mon, 10 Nov 2026 18:00:00 +0000</pubDate><description>Retail Paladin Holy Strike tweak.</description></item>
</channel></rss>"""

ATOM = """<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom">
<entry><title>1.60.1.70901</title><link href="https://github.com/Gethe/wow-ui-source/commit/x"/>
<updated>2026-11-11T04:00:00Z</updated></entry></feed>"""

PAGE1 = "<html><body><p>Hotfix list for WoW Forever launch week is here.</p><script>var t=1</script></body></html>"
PAGE2 = PAGE1.replace("</body>", "<p>Paladin: Consecration now deals the correct damage again.</p></body>")

SOURCES = [
    {"name": "Blizzard Tracker RSS (blue posts incl. Forever hotfixes/tuning)", "type": "rss", "source_url": "https://us.forums.blizzard.com/en/wow/groups/blizzard-tracker/posts.rss"},
    {"name": "Gethe/wow-ui-source forever branch commits (build number changes)", "type": "atom", "source_url": "u:atom"},
    {"name": "Blizzard hotfixes article (updated in place)", "type": "page", "source_url": "u:page"},
]


class PollerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.data = self.tmp / "data.json"
        self.data.write_text(json.dumps({"change_sources": SOURCES, "talent_and_other_spell_ids": [{"name": "Missile Barrage"}]}))
        self.out = self.tmp / "Changes.lua"
        self.state = self.tmp / "state.json"
        self.pages = {"https://us.forums.blizzard.com/en/wow/groups/blizzard-tracker/posts.rss": RSS, "u:atom": ATOM, "u:page": PAGE1}

    def fetch(self, url):
        return "text/xml", self.pages[url]

    def args(self, **kw):
        ns = type("A", (), {})()
        ns.output, ns.data, ns.state, ns.dry_run, ns.verbose = [str(self.out)], str(self.data), str(self.state), False, False
        for k, v in kw.items():
            setattr(ns, k, v)
        return ns

    def test_filters_and_writes_lua(self):
        self.assertEqual(poller.run(self.args(), fetcher=self.fetch), 0)
        lua = self.out.read_text()
        self.assertIn("Holy Strike damage increased", lua)
        self.assertIn("Client build", lua)
        self.assertNotIn("Retail: Paladin", lua, "non-Forever item dropped")
        self.assertNotIn("Warrior tuning", lua, "non-Paladin Forever item dropped")
        # valid Lua
        lua = shutil.which("lua5.1") or shutil.which("lua")
        if not lua:
            self.skipTest("no lua interpreter")
        r = subprocess.run([lua, "-e", f"local ns={{}} assert(loadfile('{self.out}'))('x', ns) assert(#ns.Data.Changes.items == 2)"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_page_baseline_then_diff_and_dedupe(self):
        poller.run(self.args(), fetcher=self.fetch)
        self.assertNotIn("Consecration now deals", self.out.read_text())
        self.pages["u:page"] = PAGE2
        poller.run(self.args(), fetcher=self.fetch)
        lua = self.out.read_text()
        self.assertIn("Consecration now deals", lua)
        poller.run(self.args(), fetcher=self.fetch)
        self.assertEqual(self.out.read_text().count("Consecration now deals"), 1)

    def test_failed_source_does_not_abort(self):
        def flaky(url):
            if url == "u:atom":
                raise OSError("boom")
            return self.fetch(url)
        self.assertEqual(poller.run(self.args(), fetcher=flaky), 0)

    def test_all_sources_failing_keeps_file(self):
        def dead(url):
            raise OSError("offline")
        self.assertEqual(poller.run(self.args(), fetcher=dead), 2)
        self.assertFalse(self.out.exists())


if __name__ == "__main__":
    unittest.main()
