% ヴィヴァルディ「夏」第 3 楽章（Presto）を、パートごとの MIDI に書き出すための原稿（build.sh が使う）。
% 楽譜そのものは同じディレクトリの Mutopia の原稿（summer3*.ly。CC BY-SA 3.0）。build.sh が convert-ly で 2.24 の書き方に直してから読む。
\version "2.24.0"
\include "articulate.ly"
\include "summer3.ly"
\include "summer3a.ly"
\include "summer3b.ly"
\include "summer3c.ly"
\include "summer3d.ly"
\score {
  \articulate <<
    \new Staff = "solo" \with { midiInstrument = "violin" } \ViolinoPrincipaleSummerThree
    \new Staff = "violinone" \with { midiInstrument = "violin" } \ViolinoPrimoSummerThree
    \new Staff = "violintwo" \with { midiInstrument = "violin" } \ViolinoSecondoSummerThree
    \new Staff = "viola" \with { midiInstrument = "viola" } \AltoViolaSummerThree
    \new Staff = "cello" \with { midiInstrument = "cello" } \VioloncelloSummerThree
  >>
  \midi { \tempo 4 = 120 }
}
