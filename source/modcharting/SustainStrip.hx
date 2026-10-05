package modcharting;

import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;
import openfl.geom.Vector3D;
import funkin.play.notes.Note;
#if ne
import funkin.graphics.shaders.RGBShader.RGBGraphics;
import flixel.FlxCamera;
#end
import flixel.FlxStrip;

class SustainStrip extends FlxStrip implements IFlxDestroyable
{
    private static final noteUV:Array<Float> = [
        0,0, //top left
        1,0, //top right
        0,0.5, //half left
        1,0.5, //half right    
        0,1, //bottom left
        1,1, //bottom right 
    ];
    private static final noteIndices:Array<Int> = [
        0,1,2,1,3,2, 2,3,4,3,4,5
        //makes 4 triangles
    ];

    private var daNote:Note;
    #if ne
    public var rgbShader:RGBGraphics = new RGBGraphics();
    #end

    override public function new(daNote:Note)
    {
        this.daNote = daNote;
        daNote.alpha = 1;
        super(0,0);
        #if ne
        rgbShader = daNote.rgbShader;
        #end
        shader = daNote.shader;

        loadGraphic(daNote.updateFramePixels());

        for (uv in noteUV)
        {
            uvtData.push(uv);
            vertices.push(0);
        }
        for (ind in noteIndices)
            indices.push(ind);
    }

    var _alpha:Float = 1;
    // TODO: check this for cases when zoom is less than initial zoom...
    public function drawData(cameraStuff:Array<FlxCamera>):Void
    {
        if (alpha <= 0 || !visible || graphic == null || vertices == null)
            return;

        // Iterate every camera rather than assigning `cameras` and using the single
        // `camera` field.
        //
        // `FlxBasic.camera` is `_cameras[0]` (FlxBasic.hx:184), so setting `cameras`
        // and reading `camera` draws only the first camera. That was fine before
        // because a sustain strip lives on the default camera, but it breaks as soon
        // as the note is assigned to a different one - the strip then draws on the
        // wrong camera, and with `cacheGPU` on it ends up on a draw item the GPU has
        // no texture bound for, so the sustain disappears entirely.
        //
        // Loop and draw per camera instead, which is what this did originally.
        for (cam in cameraStuff)
        {
            if (cam == null || !cam.visible || !cam.exists) continue;

            getScreenPosition(_point, cam).subtractPoint(offset);

            #if ne
            _alpha = this.alpha;
            rgbShader.alpha = _alpha;
            this.alpha = 1;
            #end

            #if !flash
            cam.drawTriangles(graphic, vertices, indices, uvtData, colors, _point, blend, repeat, antialiasing, colorTransform, shader);
            #else
            cam.drawTriangles(graphic, vertices, indices, uvtData, colors, _point, blend, repeat, antialiasing);
            #end

            #if ne
            this.alpha = _alpha;
            #end

            #if ne
            if (rgbShader != null)
                rgbShader.pushTriangles(cam, indices.length);
            #end
        }
    }

    /* #if ne
    override function drawComplex(camera:FlxCamera):Void
    {
        super.drawComplex(camera);
        
        if (this.rgbShader != null)
            this.rgbShader.pushTriangles(camera);
    }

    override function drawSimple(camera:FlxCamera)
    {
        super.drawSimple(camera);

        if (this.rgbShader != null)
            this.rgbShader.pushTriangles(camera);
    }
    #end */

    private static var rVerts:Array<Float> = [];
    //private static var rYOffset:Float = -1;
    inline public function constructVertices(noteData:NotePositionData, thisNotePos:Vector3D, nextHalfNotePos:NotePositionData, nextNotePos:NotePositionData, flipGraphic:Bool, reverseClip:Bool)
    {
        //var yOffset = -1; //fix small gaps
        /*  rYOffset = -1; //fix small gaps
        if (reverseClip)
            rYOffset *= -1; */

        //var verts:Array<Float> = [];
        rVerts = [];
        if (flipGraphic)
        {
            rVerts.push(nextNotePos.x);
            rVerts.push(nextNotePos.y); //slight offset to fix small gaps
            rVerts.push(nextNotePos.x+(daNote.frameWidth*(1/-nextNotePos.z)*noteData.scaleX));
            rVerts.push(nextNotePos.y);

            rVerts.push(nextHalfNotePos.x);
            rVerts.push(nextHalfNotePos.y);
            rVerts.push(nextHalfNotePos.x+(daNote.frameWidth*(1/-nextHalfNotePos.z)*noteData.scaleX));
            rVerts.push(nextHalfNotePos.y);

            rVerts.push(thisNotePos.x);
            rVerts.push(thisNotePos.y);
            rVerts.push(thisNotePos.x+(daNote.frameWidth*(1/-thisNotePos.z)*nextNotePos.scaleX));
            rVerts.push(thisNotePos.y);
        }
        else
        {
            rVerts.push(thisNotePos.x);
            rVerts.push(thisNotePos.y); //fliped this with the down ones (last) to test if it bugs of it fixes itself
            rVerts.push(thisNotePos.x+(daNote.frameWidth*(1/-thisNotePos.z)*noteData.scaleX));
            rVerts.push(thisNotePos.y);

            rVerts.push(nextHalfNotePos.x);
            rVerts.push(nextHalfNotePos.y);
            rVerts.push(nextHalfNotePos.x+(daNote.frameWidth*(1/-nextHalfNotePos.z)*noteData.scaleX));
            rVerts.push(nextHalfNotePos.y);

            rVerts.push(nextNotePos.x);
            rVerts.push(nextNotePos.y); //slight offset to fix small gaps
            rVerts.push(nextNotePos.x+(daNote.frameWidth*(1/-nextNotePos.z)*nextNotePos.scaleX));
            rVerts.push(nextNotePos.y);
        }
        vertices = new DrawData(12, true, rVerts);
    }
}