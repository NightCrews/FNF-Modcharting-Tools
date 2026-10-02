
import flixel.addons.ui.FlxUIDropDownMenu;
import funkin.play.song.Song.SwagSection;
import funkin.play.states.PlayState;
import funkin.backend.CoolUtil;
import funkin.backend.Conductor;
import funkin.backend.ClientPrefs;
import funkin.backend.Paths;
import funkin.ui.transition.LoadingState;
import funkin.backend.Difficulty;
import funkin.ui.MusicBeatSubstate;
import funkin.play.notes.Note;
import funkin.play.notes.StrumNote;
import funkin.play.song.Song;

#if LUA_ALLOWED
import funkin.backend.psychlua.FunkinLua;
import funkin.backend.psychlua.HScript as FunkinHScript;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

import flixel.FlxSprite;