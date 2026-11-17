"""Checks data/questions.gd for duplicate / near-duplicate questions and for
questions whose correct answer also appears in another question.

usage: python tools/tests/check_questions.py
"""
import difflib
import re
from collections import defaultdict

s = open("data/questions.gd", encoding="utf-8").read()
ENTRY = re.compile(r'\{"q": "((?:[^"\\]|\\.)*)", "choices": \[([^\]]*)\], "answer": (\d)')
lists = {}
for name in ["QUESTIONS", "HARD", "BUGTONG"]:
    a = s.index("const %s := [" % name)
    b = s.index("\n]", a)
    lists[name] = ENTRY.findall(s[a:b])
print({n: len(v) for n, v in lists.items()})
allq = []
for n, entries in lists.items():
    for i, (q, c, ans) in enumerate(entries):
        choices = re.findall(r'"((?:[^"\\]|\\.)*)"', c)
        allq.append((n, i, q, choices, int(ans)))
        if len(choices) != 4:
            print("NOT 4 CHOICES:", n, i, q[:70])
        if len(set(x.lower() for x in choices)) != 4:
            print("REPEATED CHOICE:", n, i, q[:70], choices)


def norm(t):
    return re.sub(r"[^a-z0-9 ]", "", t.lower())


def key(answer):
    return answer.lower().split(" (")[0].strip()


found = 0
for x in range(len(allq)):
    for y in range(x + 1, len(allq)):
        r = difflib.SequenceMatcher(None, norm(allq[x][2]), norm(allq[y][2])).ratio()
        if r > 0.6:
            found += 1
            print(f"SIMILAR {r:.2f}: [{allq[x][0]} {allq[x][1]}] {allq[x][2][:80]}\n          <-> [{allq[y][0]} {allq[y][1]}] {allq[y][2][:80]}")
by_answer = defaultdict(list)
for n, i, q, ch, a in allq:
    by_answer[key(ch[a])].append(f"[{n} {i}] {q[:70]}")
for k, v in by_answer.items():
    if len(v) > 1:
        print(f"SAME ANSWER '{k}':\n   " + "\n   ".join(v))
print("near-duplicates:", found)
