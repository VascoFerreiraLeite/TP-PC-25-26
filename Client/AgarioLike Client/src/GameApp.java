import processing.core.PApplet;

public class GameApp extends PApplet {

    GameClient client;
    String username = "Player1";

    // Player State
    float playerX = 250;
    float playerY = 250;
    float playerAngle = 0;
    float playerRadius = 20; // Calculated from mass

    // Input Flags
    int leftPressed = 0;
    int rightPressed = 0;
    int forwardPressed = 0;

    public static void main(String[] args) {
        PApplet.main("GameApp");
    }

    public void settings() {
        size(800, 600); // Made the window a bit bigger
    }

    public void setup() {
        client = new GameClient(this); // Pass reference to this app
        client.connect("localhost", 8080);
        client.sendLogin(username);
    }

    // Called by the client thread when Erlang sends an update
    public void updatePlayerState(float x, float y, float angle, float mass) {
        this.playerX = x;
        this.playerY = y;
        this.playerAngle = angle;
        // Area = mass -> Pi * r^2 = mass -> r = sqrt(mass/pi)
        // Multiply by a scaling factor so it looks good on screen
        this.playerRadius = (float) (Math.sqrt(mass / Math.PI)) * 10;
    }

    public void draw() {
        background(255, 255, 255);

        // Draw the player
        pushMatrix();
        translate(playerX, playerY);
        rotate(playerAngle);

        // Body (Black as per PDF)
        fill(0);
        stroke(0, 0, 255); // Blue border for own player
        strokeWeight(3);
        circle(0, 0, playerRadius * 2);

        // Draw a line to show the direction the player is facing
        stroke(255, 0, 0);
        line(0, 0, playerRadius, 0);

        popMatrix();
    }

    public void keyPressed() {
        boolean changed = false;
        if (keyCode == LEFT)  { leftPressed = 1; changed = true; }
        if (keyCode == RIGHT) { rightPressed = 1; changed = true; }
        if (keyCode == UP)    { forwardPressed = 1; changed = true; }

        if (changed) client.sendMovement(leftPressed, rightPressed, forwardPressed);
    }

    public void keyReleased() {
        boolean changed = false;
        if (keyCode == LEFT)  { leftPressed = 0; changed = true; }
        if (keyCode == RIGHT) { rightPressed = 0; changed = true; }
        if (keyCode == UP)    { forwardPressed = 0; changed = true; }

        if (changed) client.sendMovement(leftPressed, rightPressed, forwardPressed);
    }
}