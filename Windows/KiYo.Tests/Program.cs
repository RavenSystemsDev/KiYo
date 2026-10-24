using KiYo.Core;
using System.Diagnostics;
using System.Text.Json;

int assertions = 0;
void Check(bool value, string name) { assertions++; if (!value) throw new Exception("FAILED: " + name); }
void Equal<T>(T expected, T actual, string name) => Check(EqualityComparer<T>.Default.Equals(expected, actual), name);

Equal("привет", Layouts.Convert("ghbdtn"), "EN to RU");
Equal("hello", Layouts.Convert("руддщ"), "RU to EN");
Equal("ПРИВЕТ", Layouts.Convert("GHBDTN"), "uppercase");
Equal("привет, мир!\r\nhello 😀", Layouts.ConvertSelection("ghbdtn, vbh!\r\nруддщ 😀"), "selection punctuation and emoji");
Equal("Привет\thello", Layouts.ConvertSelection("Ghbdtn\tруддщ"), "tabs and case");
foreach (var input in new[] { "kiyo", "KIYO", "KiYO", "ЛшНщ", "лшнщ" }) Equal("KiYo", Layouts.Correct(input, true, []), "brand " + input);
foreach (var input in new[] { "РУ", "Ру", "ру", "hello", "привет", "d", "j" }) Equal<string?>(null, Layouts.Correct(input, true, []), "protected or valid " + input);
Equal("CRM", Layouts.Correct("СКЬ", true, []), "technical term");
Equal("postgres", Layouts.Correct("зщыепкуы", true, []), "developer word");
Equal("hi", Layouts.Correct("рш", true, []), "short enabled");
Equal<string?>(null, Layouts.Correct("рш", false, []), "short disabled");
foreach (var input in new[] { "ghbdtn@example.com", "www.ghbdtn.com", "https://ghbdtn.com", "ghbdtn123", "ghbdtn_file", @"C:\ghbdtn" })
 Equal<string?>(null, Layouts.Correct(input, true, []), "address and identifier " + input);
Equal<string?>(null, Layouts.Correct("ghbdtn", true, ["привет"]), "exclude other layout");
Equal<string?>(null, Layouts.Correct("ghbdtn,", true, ["ghbdtn"]), "exclude punctuation");
Equal<string?>(null, Layouts.Correct("fdnjvjnj", true, [], (_, _) => null), "no invented unavailable dictionary");
Equal("автомото", Layouts.Correct("fdnjvjnj", true, [], (_, ru) => ru), "system word validation");
Check(Layouts.ExclusionsFromSelection("Hello, HELLO\nKiYo!").SequenceEqual(new[] { "hello", "kiyo" }), "normalize exclusions");
Equal(0, Layouts.ExclusionsFromSelection(new string('a', 513)).Length, "bounded exclusions");
try { Layouts.ConvertSelection(new string('a', 8193)); throw new Exception("unbounded selection"); } catch (ArgumentOutOfRangeException) { assertions++; }

var now = DateTimeOffset.UtcNow;
WordAttempt Word(TypingState state, string word)
{
 foreach (var c in word) state.Character(c);
 return state.Space(now)!;
}
var typing = new TypingState(); typing.Context(1, 0x409);
var attempt = Word(typing, "ghbdtn");
Check(typing.Current(attempt), "pending token current");
typing.Character('h'); Check(!typing.Current(attempt), "typing cancels async replacement");
typing.Invalidate();attempt = Word(typing, "ghbdtn");
typing.Context(2, 0x409); Check(!typing.Current(attempt), "window switch cancels");
attempt = Word(typing, "ghbdtn");typing.Context(2, 0x419);Check(!typing.Current(attempt), "external layout switch cancels");
attempt = Word(typing, "ghbdtn");typing.Invalidate();Check(!typing.Current(attempt), "click or setting cancels");
foreach (var c in new string('q', 70)) typing.Character(c);
Check(typing.Space(now) == null, "long token not corrected in part");
Check(Word(typing, "ghbdtn").Word == "ghbdtn", "recover after long token");
typing.Invalidate(); attempt = Word(typing, "ghbdtn");typing.Corrected(attempt, 6, now);
for (int i = 0; i < 7; i++) typing.Backspace(now);
foreach (var c in "ghbdtn") typing.Character(c);
Check(typing.Space(now) == null, "manual rejection respected once");
Check(Word(typing, "ghbdtn") != null, "rejection not permanent");

var pref = new Preferences { Language = "bad", Exclusions = ["HELLO", "hello", "bad\nword"], ConvertShortcut = new(0, 0), ExcludeShortcut = new(0, 0) }.Normalize();
Equal("system", pref.Language, "invalid language");Equal(1, pref.Exclusions.Length, "sanitize exclusions");
Check(pref.ConvertShortcut.Valid && pref.ExcludeShortcut.Valid, "normalize hotkeys");
Check(!new Shortcut(0, 'A').Valid && !new Shortcut(16, 'R').Valid, "invalid hotkeys");
var collision = new Preferences { ConvertShortcut = new(3, 'K'), ExcludeShortcut = new(3, 'K') }.Normalize();
Check(collision.ConvertShortcut != collision.ExcludeShortcut, "duplicate hotkeys normalized");
var file = Path.Combine(Path.GetTempPath(), "kiyo-test-" + Guid.NewGuid(), "settings.json");
try
{
 pref.Save(file);Equal("hello", Preferences.Read(file).Exclusions.Single(), "settings roundtrip");
 File.WriteAllText(file, "{broken");Check(Preferences.Read(file).Enabled, "corrupt settings safe defaults");
 File.WriteAllText(file, new string('x', 256 * 1024 + 1));Check(Preferences.Read(file).Enabled, "oversized settings");
}
finally { Directory.Delete(Path.GetDirectoryName(file)!, true); }

var timer = Stopwatch.StartNew();
for (int i = 0; i < 10000; i++)
{
 foreach (var (input, output) in new[] { ("ghbdtn", "привет"), ("рш", "hi"), ("rfr", "как"), ("ltkf", "дела") })
 {
  typing.Context(1, Layouts.IsRussian(input) ? 0x419 : 0x409);
  var word = Word(typing, input);
  Equal(output, Layouts.Correct(word.Word, true, []), "alternating phrase");
  typing.Corrected(word, output.Length, now);
 }
}
Console.WriteLine($"PASS: {assertions} assertions; 10,000 alternating phrases in {timer.ElapsedMilliseconds} ms. No system input was generated.");
