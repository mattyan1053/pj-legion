% ヴィヴァルディ「冬」第 1 楽章（Allegro non molto）を、パートごとの MIDI に書き出すための原稿（build.sh が使う）。
% 楽譜そのものは同じディレクトリの Mutopia の原稿（winter1*.ly。CC BY-SA 3.0）。build.sh が convert-ly で 2.24 の書き方に直してから読む。
% articulate.ly は、トリルとスタッカートを MIDI の音に書き下す（LilyPond の同梱物）。
\version "2.24.0"
\include "articulate.ly"
\include "winter1.ly"
\include "winter1a.ly"
\include "winter1b.ly"
\include "winter1c.ly"
\include "winter1d.ly"
\score {
  \articulate <<
    \new Staff = "solo" \with { midiInstrument = "violin" } \ViolinoPrincipaleWinterOne
    \new Staff = "violinone" \with { midiInstrument = "violin" } \ViolinoPrimoWinterOne
    \new Staff = "violintwo" \with { midiInstrument = "violin" } \ViolinoSecondoWinterOne
    \new Staff = "viola" \with { midiInstrument = "viola" } \AltoViolaWinterOne
    \new Staff = "cello" \with { midiInstrument = "cello" } \VioloncelloWinterOne
  >>
  \midi { \tempo 4 = 120 }
}
