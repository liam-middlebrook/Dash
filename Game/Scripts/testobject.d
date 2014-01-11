module testobject;
import core.gameobject;
import utility.output;

class TestObject : GameObject
{
	// Overridables
	override void onUpdate()
	{

	}

	/// Called on the draw cycle.
	override void onDraw() { }
	/// Called on shutdown.
	override void onShutdown() { }
	/// Called when the object collides with another object.
	override void onCollision( GameObject other ) { }
}