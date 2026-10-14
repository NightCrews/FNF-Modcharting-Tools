package modcharting;

import flixel.tweens.misc.BezierPathTween;
import flixel.tweens.misc.BezierPathNumTween;
import flixel.util.FlxTimer.FlxTimerManager;
import flixel.graphics.FlxGraphic;
import flixel.FlxStrip;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import openfl.geom.Vector3D;
import flixel.util.FlxSpriteUtil;
import flixel.graphics.frames.FlxFrame;
import modcharting.Modifier;
import managers.*;
import managers.TweenManager;
#if LEATHER
import states.PlayState;
import game.Note;
import game.StrumNote;
import game.Conductor;
#elseif (PSYCH && PSYCHVERSION >= "0.7")
import funkin.play.notes.Note;
import funkin.play.notes.StrumNote;
import funkin.play.states.PlayState;
#else
import PlayState;
import Note;
import StrumNote;
#end

using StringTools;

// a few todos im gonna leave here:
// setup quaternions for everything else (incoming angles and the rotate mod)
// do add and remove buttons on stacked events in editor
// fix switching event type in editor so you can actually do set events
// finish setting up tooltips in editor
// start documenting more stuff idk

typedef StrumNoteType = #if (PSYCH || LEATHER) StrumNote #elseif KADE StaticArrow #elseif FOREVER_LEGACY UIStaticArrow #elseif ANDROMEDA Receptor #else FlxSprite #end;

class PlayfieldRenderer extends funkin.graphics.FunkinSprite implements IFlxDestroyable // extending flxsprite just so i can edit draw
{
	public var strumGroup:FlxTypedGroup<StrumNoteType>;
	public var notes:FlxTypedGroup<Note>;
	public var instance:ModchartMusicBeatState;
	public var playStateInstance:PlayState;
	public var playfields:Array<Playfield> = []; // adding an extra playfield will add 1 for each player

	public var eventManager:ModchartEventManager;
	public var modifierTable:ModTable;
	public var tweenManager:TweenManager = null;
	public var timerManager:FlxTimerManager = null;

	public var modchart:ModchartFile;
	public var inEditor:Bool = false;
	public var editorPaused:Bool = false;

	public var speed:Float = 1.0;

	public var modifiers(get, default):Map<String, Modifier>;

	private function get_modifiers():Map<String, Modifier>
		return modifierTable.modifiers; // back compat with lua modcharts

	public function new(strumGroup:FlxTypedGroup<StrumNoteType>, notes:FlxTypedGroup<Note>, instance:ModchartMusicBeatState)
	{
		super();
		this.strumGroup = strumGroup;
		this.notes = notes;
		this.instance = instance;
		if (Std.isOfType(instance, PlayState))
			playStateInstance = cast instance; // so it just casts once

		strumGroup.visible = false; // drawing with renderer instead
		notes.visible = false;

		// fix stupid crash because the renderer in playstate is still technically null at this point and its needed for json loading
		instance.playfieldRenderer = this;

		tweenManager = new TweenManager();
		timerManager = new FlxTimerManager();
		eventManager = new ModchartEventManager(this);
		modifierTable = new ModTable(instance, this);
		addNewPlayfield(0, 0, 0);
		modchart = new ModchartFile(this);
	}

	public function addNewPlayfield(?x:Float = 0, ?y:Float = 0, ?z:Float = 0, ?alpha:Float = 1)
		playfields.push(new Playfield(x, y, z, alpha));

	override function update(elapsed:Float)
	{
		try
		{
			if (eventManager != null)
				eventManager.update(elapsed);
			if (tweenManager != null)
				tweenManager.update(elapsed); // should be automatically paused when you pause in game
			if (timerManager != null)
				timerManager.update(elapsed);
		}
		catch (e)
		{
			// trace(e);
		}
		super.update(elapsed);
	}

	override public function draw()
	{
		if (!visible || !active)
			return;

		if (inEditor)
		{
			strumGroup.cameras = this.cameras;
			notes.cameras = this.cameras;
		}

		//for (camera in cameras)
		{
			if (!camera.visible || !camera.exists /*  || !isOnScreen(camera) */)
				return; //continue;

			getScreenPosition(_point, camera).subtractPoint(offset);
		}

		try
		{
			drawStuff(getNotePositions());
		}
		catch (e)
		{
			trace(e);
		}
		//drawStuff(getNotePositions());
		// draw notes to screen
	}

	inline private function addDataToStrum(strumData:NotePositionData, strum:StrumNoteType)
	{
		strum.x = strumData.x;
		strum.y = strumData.y;
		// Add Z to your strumNoteType if you want it youself!
		//strum.z = strumData.z;
		strum.angle = strumData.angle;
		#if ne
		strum.manualAlpha = true;
		strum.rgbShader.alpha = strumData.alpha;
		#else
		strum.alpha = strumData.alpha;
		#end
		strum.scale.x = strumData.scaleX;
		strum.scale.y = strumData.scaleY;
		strum.skew.x = strumData.skewX;
		strum.skew.y = strumData.skewY;
	}

	private function getDataForStrum(i:Int, pf:Int)
	{
		//final strumX = NoteMovement.defaultStrumX[i];
		//final strumY = NoteMovement.defaultStrumY[i];
		//final strumZ = 0;
		var strumScaleX = NoteMovement.defaultScale[i];
		var strumScaleY = NoteMovement.defaultScale[i];
		//final strumSkewX = NoteMovement.defaultSkewX[i];
		//final strumSkewY = NoteMovement.defaultSkewY[i];
		if (ModchartUtil.getIsPixelStage(instance))
		{
			// work on pixel stages
			strumScaleX = 1 * PlayState.daPixelZoom;
			strumScaleY = 1 * PlayState.daPixelZoom;
		}
		final strumData:NotePositionData = NotePositionData.get();
		strumData.setupStrum(NoteMovement.defaultStrumX[i], NoteMovement.defaultStrumY[i], 0, i, strumScaleX, strumScaleY, NoteMovement.defaultSkewX[i], NoteMovement.defaultSkewY[i], pf);
		playfields[pf].applyOffsets(strumData);
		modifierTable.applyStrumMods(strumData, i, pf);
		return strumData;
	}

	inline private function addDataToNote(noteData:NotePositionData, daNote:Note)
	{
		daNote.x = noteData.x;
		daNote.y = noteData.y;
		daNote.z = noteData.z;
		daNote.angle = noteData.angle;
		#if ne
		daNote.manualAlpha = true;
		daNote.rgbShader.alpha = noteData.alpha;
		#else
		daNote.alpha = noteData.alpha;
		#end
		daNote.scale.x = noteData.scaleX;
		daNote.scale.y = noteData.scaleY;
		daNote.skew.x = noteData.skewX;
		daNote.skew.y = noteData.skewY;
	}

	private function createDataFromNote(noteIndex:Int, playfieldIndex:Int, curPos:Float, noteDist:Float, incomingAngle:Array<Float>)
	{
		/* final noteX = notes.members[noteIndex].x;
		final noteY = notes.members[noteIndex].y;
		final noteZ = notes.members[noteIndex].z; */
		if (notes == null || notes.members == null || noteIndex < 0 || noteIndex >= notes.members.length || notes.members[noteIndex] == null)
			return NotePositionData.get(); // return empty data
		
		final lane = getLane(noteIndex);
		var noteScaleX = NoteMovement.defaultScale[lane];
		var noteScaleY = NoteMovement.defaultScale[lane];
		/* final noteSkewX = notes.members[noteIndex].skew.x;
		final noteSkewY = notes.members[noteIndex].skew.y; */

		final noteAlpha:Float = #if PSYCH notes.members[noteIndex].multAlpha; #else notes.members[noteIndex].isSustainNote ? 0.6 : 1; #end

		if (ModchartUtil.getIsPixelStage(instance))
		{
			// work on pixel stages
			noteScaleX = 1 * PlayState.daPixelZoom;
			noteScaleY = 1 * PlayState.daPixelZoom;
		}

		final noteData:NotePositionData = NotePositionData.get();
		noteData.setupNote(notes.members[noteIndex].x, notes.members[noteIndex].y, notes.members[noteIndex].z, lane, noteScaleX, noteScaleY, notes.members[noteIndex].skew.x, notes.members[noteIndex].skew.y, playfieldIndex, noteAlpha, curPos, noteDist,
			incomingAngle[0], incomingAngle[1], notes.members[noteIndex].strumTime, noteIndex);
		playfields[playfieldIndex].applyOffsets(noteData);
		return noteData;
	}

	private static var rDistance:Float = 0;
	private function getNoteCurPos(noteIndex:Int, strumTimeOffset:Float = 0)
	{
		if (notes == null || notes.members == null || noteIndex < 0 || noteIndex >= notes.members.length || notes.members[noteIndex] == null)
			return 0; // return default position
		
		#if PSYCH
		if (notes.members[noteIndex].isSustainNote && ModchartUtil.getDownscroll(instance))
			strumTimeOffset -= Std.int(Conductor.stepCrochet / getCorrectScrollSpeed()); // psych does this to fix its sustains but that breaks the visuals so basically reverse it back to normal
		#else
		if (notes.members[noteIndex].isSustainNote && !ModchartUtil.getDownscroll(instance))
			strumTimeOffset += Conductor.stepCrochet; // fix upscroll lol
		#end
		//final distance = (Conductor.songPosition - notes.members[noteIndex].strumTime) + strumTimeOffset;
		rDistance = (Conductor.songPosition - notes.members[noteIndex].strumTime) + strumTimeOffset;
		return Std.int(rDistance * getCorrectScrollSpeed());
	}

	private function getLane(noteIndex:Int)
	{
		if (notes == null || notes.members == null || noteIndex < 0 || noteIndex >= notes.members.length || notes.members[noteIndex] == null)
			return 0; // default lane
		return (notes.members[noteIndex].mustPress ? notes.members[noteIndex].noteData + NoteMovement.keyCount : notes.members[noteIndex].noteData);
	}

	private static var rNoteDist:Float = -0.45;
	private function getNoteDist(noteIndex:Int)
	{
		//var noteDist = -0.45;
		rNoteDist = -0.45;
		if (notes != null && notes.members != null && noteIndex >= 0 && noteIndex < notes.members.length && notes.members[noteIndex] != null)
		{
			if (ModchartUtil.getDownscroll(instance))
				rNoteDist *= -1;
		}
		return rNoteDist;
	}

	private static var rNotePositions:Array<NotePositionData> = [];

	/**
	 * How far past the strumline a note may still be drawn, in the same units
	 * `getNoteCurPos()` returns (pixels, scroll speed already applied).
	 *
	 * `NoteGroup` culls with a 1000ms time limit; this is the matching distance. Notes
	 * further out cannot contribute a visible pixel, so they are skipped outright
	 * instead of running the whole modifier/perspective pipeline for them.
	 */
	static inline final pfNoteCutoff:Float = 4000;

	/**
	 * First note that can still be on screen.
	 *
	 * `notes` is sorted by strumTime and the song position only ever moves forward, so
	 * this only ever advances - the classic sliding window. Previously the loop walked
	 * all members every frame, which on chart-heavy songs ran the full modifier +
	 * perspective pipeline (twice more per sustain, via `getSustainPoint()`) for
	 * thousands of notes nowhere near the playfield.
	 *
	 * `NoteGroup.startIndex` would be the natural place for this, but `notes` is typed
	 * as `FlxTypedGroup<Note>` because the modchart editor passes a plain group, so the
	 * renderer keeps its own index instead.
	 */
	private var pfStartIndex:Int = 0;
	private function getNotePositions()
	{
		//var notePositions:Array<NotePositionData> = [];
		rNotePositions = [];
		
		if (notes == null || notes.members == null || playfields == null || strumGroup == null || strumGroup.members == null)
			return rNotePositions;

		// The window is meaningless if the note group was swapped out (song restart,
		// editor reload) and can outrun a shorter list.
		if (pfStartIndex > notes.members.length)
			pfStartIndex = 0;

		for (pf in 0...playfields.length)
		{
			for (i in 0...strumGroup.members.length)
			{
				//final strumData = getDataForStrum(i, pf);
				rNotePositions.push(getDataForStrum(i, pf));
			}

			// The cursor is only sound while the note group is ordered oldest-first.
			// PlayState guarantees that, but the modchart editor does not: it spawns with
			// `notes.insert(0, note)`, so the group is newest-first, and `clearNotesAfter()`
			// / the pass-by loop splice members out of it as the playhead advances. Every
			// one of those shifts later indices down while the cursor keeps climbing, so it
			// drifts past the notes it is meant to be tracking - the loop then breaks on its
			// first `curPos < -pfNoteCutoff` test and the playfield comes up blank, in either
			// direction, as soon as the window desyncs.
			//
			// The editor only ever holds the notes near the playhead (it spawns 2000 ms
			// ahead and clears behind), so it scans the whole group per frame and filters on
			// both ends instead. Same work as before per note - no modifiers, no perspective,
			// no allocation for anything off screen - just without a cursor to keep in sync.
			final scanAll:Bool = inEditor;
			final first:Int = scanAll ? 0 : pfStartIndex;
			for (i in first...notes.members.length)
			{
				var daNote = notes.members[i];
				if (daNote == null)
				{
					// keep the window aligned if there is a hole in the group
					if (i == pfStartIndex) pfStartIndex++;
					continue;
				}

				// Cheap gate first: only the position, no modifiers or perspective yet.
				// `curPos` is negative ahead of the song position and positive behind
				// it, so once we reach notes in the future nothing further can be drawn
				// and this loop must stop.
				final rawCurPos = getNoteCurPos(i, 0);
				if (rawCurPos < -pfNoteCutoff)
				{
					if (!scanAll) break;
					continue;
				}

				// Advance the window past notes that are already gone. `curPos` can still
				// be pinned to 0 further down for sustains that were hit, so only skip
				// notes far enough in the past that no modifier could pull them back.
				if (rawCurPos > pfNoteCutoff)
				{
					pfStartIndex = i + 1;
					continue;
				}

				var songSpeed = getCorrectScrollSpeed();
				var lane = getLane(i);
				var noteDist = getNoteDist(i);
				noteDist = modifierTable.applyNoteDistMods(noteDist, lane, pf);

				var curPos = Std.int(rawCurPos);
				curPos = Std.int(modifierTable.applyCurPosMods(lane, curPos, pf));

				if ((daNote.wasGoodHit || (daNote.prevNote.wasGoodHit))
					&& curPos >= 0
					&& daNote.isSustainNote)
					curPos = 0; // sustain clip

				var incomingAngle:Array<Float> = modifierTable.applyIncomingAngleMods(lane, curPos, pf);
				if (noteDist < 0)
					incomingAngle[0] += 180; // make it match for both scrolls

				// get the general note path
				NoteMovement.setNotePath(daNote, lane, songSpeed, curPos, noteDist, incomingAngle[0], incomingAngle[1]);

				// save the position data
				var noteData = createDataFromNote(i, pf, curPos, noteDist, incomingAngle);

				// add offsets to data with modifiers
				modifierTable.applyNoteMods(noteData, lane, curPos, pf);

				// add position data to list
				rNotePositions.push(noteData);
			}
		}
		// sort by z before drawing
		rNotePositions.sort(function(a, b)
		{
			if (a.z < b.z)
				return -1;
			else if (a.z > b.z)
				return 1;
			else
				return 0;
		});
		return rNotePositions;
	}

	private function drawStrum(noteData:NotePositionData)
	{
		if (!strumGroup.members[noteData.index].visible || !strumGroup.members[noteData.index].active)
			return;
		final changeX:Bool = ((noteData.z > 0 || noteData.z < 0) && noteData.z != 0);
		final strumNote = strumGroup.members[noteData.index];
		var thisNotePos = changeX ? ModchartUtil.calculatePerspective(new Vector3D(noteData.x + (strumNote.width / 2), noteData.y + (strumNote.height / 2),
			noteData.z * 0.001),
			ModchartUtil.defaultFOV * (Math.PI / 180),
			-(strumNote.width / 2),
			-(strumNote.height / 2)) : new Vector3D(noteData.x, noteData.y, 0);

		noteData.x = thisNotePos.x;
		noteData.y = thisNotePos.y;
		if (changeX)
		{
			noteData.scaleX *= (1 / -thisNotePos.z);
			noteData.scaleY *= (1 / -thisNotePos.z);
		}
		// noteData.skewX = skewX + noteData.skewX;
		// noteData.skewY = skewY + noteData.skewY;

		addDataToStrum(noteData, strumGroup.members[noteData.index]); // set position and stuff before drawing
		if (inEditor)
			strumGroup.members[noteData.index].cameras = this.cameras;

		strumGroup.members[noteData.index].draw();
	}

	private function drawNote(noteData:NotePositionData)
	{
		if (noteData.alpha <= 0 || !notes.members[noteData.index].visible || !notes.members[noteData.index].active)
			return;
		final changeX:Bool = ((noteData.z > 0 || noteData.z < 0) && noteData.z != 0);
		final daNote = notes.members[noteData.index];
		final thisNotePos = changeX ? ModchartUtil.calculatePerspective(new Vector3D(noteData.x
			+ (daNote.width / 2)
			+ ModchartUtil.getNoteOffsetX(daNote, instance), noteData.y
			+ (daNote.height / 2), noteData.z * 0.001),
			ModchartUtil.defaultFOV * (Math.PI / 180),
			-(daNote.width / 2),
			-(daNote.height / 2)) : new Vector3D(noteData.x, noteData.y, 0);

		noteData.x = thisNotePos.x;
		noteData.y = thisNotePos.y;
		if (changeX)
		{
			noteData.scaleX *= (1 / -thisNotePos.z);
			noteData.scaleY *= (1 / -thisNotePos.z);
		}
		// noteData.skewX = skewX + noteData.skewX;
		// noteData.skewY = skewY + noteData.skewY;
		// set note position using the position data
		addDataToNote(noteData, notes.members[noteData.index]);
		// make sure it draws on the correct camera
		if (inEditor)
			notes.members[noteData.index].cameras = this.cameras;
		// draw it
		notes.members[noteData.index].draw();
	}

	private function drawSustainNote(noteData:NotePositionData)
	{
		if (noteData.alpha <= 0 || !notes.members[noteData.index].visible || !notes.members[noteData.index].active)
			return;
		final daNote = notes.members[noteData.index];
		if (daNote.mesh == null)
			daNote.mesh = new SustainStrip(daNote);

		daNote.mesh.scrollFactor.x = daNote.scrollFactor.x;
		daNote.mesh.scrollFactor.y = daNote.scrollFactor.y;
		daNote.alpha = noteData.alpha;
		daNote.mesh.alpha = daNote.alpha;

		final songSpeed = getCorrectScrollSpeed();
		var lane = noteData.lane;

		// makes the sustain match the center of the parent note when at weird angles
		final yOffsetThingy = (NoteMovement.arrowSizes[lane] / 2);

		final thisNotePos = ModchartUtil.calculatePerspective(new Vector3D(noteData.x
			+ (daNote.width / 2)
			+ ModchartUtil.getNoteOffsetX(daNote, instance),
			noteData.y
			+ (NoteMovement.arrowSizes[noteData.lane] / 2), noteData.z * 0.001),
			ModchartUtil.defaultFOV * (Math.PI / 180),
			-(daNote.width / 2), yOffsetThingy
			- (NoteMovement.arrowSizes[noteData.lane] / 2));

		var timeToNextSustain = ModchartUtil.getFakeCrochet() / 4;
		if (noteData.noteDist < 0)
			timeToNextSustain *= -1; // weird shit that fixes upscroll lol
		// timeToNextSustain = -ModchartUtil.getFakeCrochet()/4; //weird shit that fixes upscroll lol

		#if (PSYCH && !(PSYCHVERSION >= "0.7"))
		final nextHalfNotePos = getSustainPoint(noteData, timeToNextSustain * 0.5);
		final nextNotePos = getSustainPoint(noteData, timeToNextSustain);
		#else
		final nextHalfNotePos = ModchartUtil.getDownscroll(instance) ? getSustainPoint(noteData,
			timeToNextSustain * 0.458) : getSustainPoint(noteData, timeToNextSustain * 0.548);
		final nextNotePos = ModchartUtil.getDownscroll(instance) ? getSustainPoint(noteData,
			timeToNextSustain + 2.2) : getSustainPoint(noteData, timeToNextSustain - 2.2);
		#end

		var flipGraphic = false;

		// mod/bound to 360, add 360 for negative angles, mod again just in case
		final fixedAngY = ((noteData.incomingAngleY % 360) + 360) % 360;

		final reverseClip = (fixedAngY > 90 && fixedAngY < 270);

		if (noteData.noteDist > 0) // downscroll
		{
			if (!ModchartUtil.getDownscroll(instance)) // fix reverse
				flipGraphic = true;
		}
		else
		{
			if (ModchartUtil.getDownscroll(instance))
				flipGraphic = true;
		}

		// render that shit
		daNote.mesh.constructVertices(noteData, thisNotePos, nextHalfNotePos, nextNotePos, flipGraphic, reverseClip);

		if (inEditor)
		{
			// Use the same path the game does. `SustainStrip.draw()` is inherited straight
			// from `FlxStrip` and only issues `camera.drawTriangles(...)` - it never touches
			// `rgbShader`, so every sustain in the editor rendered untinted, and it gated on
			// `alpha == 0` with no RGB handling at all. `drawData()` is the version that
			// hands the strip's alpha to the shader and calls `pushTriangles()` afterwards,
			// which is where the per-draw-item RGB data gets written.
			daNote.mesh.cameras = this.cameras;
			daNote.mesh.drawData(this.cameras);
		}
		else if (daNote.reduce)
		{
			// render that shit
			var yOffset = -1; // fix small gaps
			if (reverseClip) yOffset *= -1;

			if (flipGraphic)
			{
				daNote.nextNote.x = (nextNotePos.x);
				daNote.nextNote.y = (nextNotePos.y); // slight offset to fix small gaps
				daNote.nextNote.y = (nextNotePos.y);

				daNote.prevNote.x = (nextHalfNotePos.x);
				daNote.prevNote.y = (nextHalfNotePos.y);
				daNote.prevNote.y = (nextHalfNotePos.y);

				noteData.x = (thisNotePos.x);
				noteData.y = (thisNotePos.y);
				noteData.y = (thisNotePos.y);
			}
			else
			{
				noteData.x = (thisNotePos.x);
				noteData.y = (thisNotePos.y); // fliped this with the down ones (last) to test if it bugs of it fixes itself
				noteData.y = (thisNotePos.y);

				daNote.prevNote.x = (nextNotePos.x);
				daNote.prevNote.y = (nextNotePos.y);
				daNote.prevNote.y = (nextNotePos.y);

				if (daNote.nextNote != null)
				{
					daNote.nextNote.x = (nextHalfNotePos.x);
					daNote.nextNote.y = (nextHalfNotePos.y); // slight offset to fix small gaps
					daNote.nextNote.y = (nextHalfNotePos.y);
				}
			}
			/*daNote.prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.05;
				if(PlayState.isPixelStage)
					daNote.scale.y *= PlayState.daPixelZoom; */
/*noteData.x = thisNotePos.x;
 				noteData.y = thisNotePos.y; */
			noteData.scaleX *= (1 / -thisNotePos.z);
			noteData.scaleY *= (1 / -thisNotePos.z);
			addDataToNote(noteData, daNote);
			daNote.draw();
		}
		else
			daNote.mesh.drawData(daNote.cameras);
	}

	private function drawStuff(notePositions:Array<NotePositionData>)
	{
		for (noteData in notePositions)
		{
			if (noteData.isStrum) // draw strum
				drawStrum(noteData);
			else if (!notes.members[noteData.index].isSustainNote) // draw regular note
				drawNote(noteData);
			else
			{ // draw sustain
				#if LEATHER /*disable the funny sustains options for low-end pc lol*/ if (utilities.Options.getData("optimizedModcharts"))
					drawNote(noteData)
				else #end drawSustainNote(noteData);
			}
		}

		// Recycle the frame's position data now that everything has consumed it.
		//
		// `NotePositionData.get()` pulls from a static `FlxPool`, but nothing ever put
		// anything back, so the pool always missed and `get()` fell through to `new`.
		// That is once per strum and note per playfield, plus two more per sustain from
		// `getSustainPoint()` - so every frame threw away `playfields * notes` (times
		// three for sustains) objects and rebuilt them, which is the garbage spike that
		// shows up as lag on chart-heavy songs such as Blue-dream and Galactic-storm.
		//
		// Nothing holds on to these past the draw: the position data feeds modifiers
		// and `constructVertices()` immediately, and the sustain points are read out as
		// `Vector3D` values rather than kept by reference. Returning them here lets the
		// pool hand the same instances back next frame instead of allocating.
		for (noteData in notePositions)
			NotePositionData.put(noteData);
	}

	function getSustainPoint(noteData:NotePositionData, timeOffset:Float):NotePositionData
	{
		final daNote:Note = notes.members[noteData.index];
		final songSpeed:Float = getCorrectScrollSpeed();
		final lane:Int = noteData.lane;
		final pf:Int = noteData.playfieldIndex;

		var noteDist:Float = getNoteDist(noteData.index);
		var curPos:Float = getNoteCurPos(noteData.index, timeOffset);

		curPos = modifierTable.applyCurPosMods(lane, curPos, pf);

		if ((daNote.wasGoodHit || (daNote.prevNote.wasGoodHit)) && curPos >= 0)
			curPos = 0;
		noteDist = modifierTable.applyNoteDistMods(noteDist, lane, pf);
		var incomingAngle:Array<Float> = modifierTable.applyIncomingAngleMods(lane, curPos, pf);
		if (noteDist < 0)
			incomingAngle[0] += 180; // make it match for both scrolls
		// get the general note path for the next note
		NoteMovement.setNotePath(daNote, lane, songSpeed, curPos, noteDist, incomingAngle[0], incomingAngle[1]);
		// save the position data
		var noteData = createDataFromNote(noteData.index, pf, curPos, noteDist, incomingAngle);
		// add offsets to data with modifiers
		modifierTable.applyNoteMods(noteData, lane, curPos, pf);
		final yOffsetThingy = (NoteMovement.arrowSizes[lane] / 2);
		final finalNotePos = ModchartUtil.calculatePerspective(new Vector3D(noteData.x
			+ (daNote.width / 2)
			+ ModchartUtil.getNoteOffsetX(daNote, instance),
			noteData.y
			+ (NoteMovement.arrowSizes[noteData.lane] / 2), noteData.z * 0.001),
			ModchartUtil.defaultFOV * (Math.PI / 180),
			-(daNote.width / 2), yOffsetThingy
			- (NoteMovement.arrowSizes[noteData.lane] / 2));

		noteData.x = finalNotePos.x;
		noteData.y = finalNotePos.y;
		noteData.z = finalNotePos.z;

		return noteData;
	}

	public function getCorrectScrollSpeed()
	{
		/* if (inEditor)
			return PlayState.SONG.speed; // just use this while in editor so the instance shit works
		else
			return ModchartUtil.getScrollSpeed(playStateInstance); */
		return inEditor ? PlayState.SONG.speed : ModchartUtil.getScrollSpeed(playStateInstance); //1.0;
	}

	public function createTween(Object:Dynamic, Values:Dynamic, Duration:Float, ?Options:TweenOptions):FlxTween
	{
		var tween:FlxTween = tweenManager.tween(Object, Values, Duration, Options);
		tween.manager = tweenManager;
		return tween;
	}

	public function createTweenNum(FromValue:Float, ToValue:Float, Duration:Float = 1, ?Options:TweenOptions, ?TweenFunction:Float->Void):FlxTween
	{
		var tween:FlxTween = tweenManager.num(FromValue, ToValue, Duration, Options, TweenFunction);
		tween.manager = tweenManager;
		return tween;
	}

	public function createBezierPathTween(Object:Dynamic, Values:Dynamic, Duration:Float, ?Options:TweenOptions):FlxTween
	{
		var tween:FlxTween = tweenManager.bezierPathTween(Object, Values, Duration, Options);
		tween.manager = tweenManager;
		return tween;
	}

	public function createBezierPathNumTween(Points:Array<Float>, Duration:Float, ?Options:TweenOptions, ?TweenFunction:Float->Void):FlxTween
	{
		var tween:FlxTween = tweenManager.bezierPathNumTween(Points, Duration, Options, TweenFunction);
		tween.manager = tweenManager;
		return tween;
	}

	override public function destroy()
	{
		if (modchart != null)
		{
			#if hscript
			for (customMod in modchart.customModifiers)
			{
				customMod.destroy(); // make sure the interps are dead
			}
			#end
		}
		super.destroy();
	}
}
