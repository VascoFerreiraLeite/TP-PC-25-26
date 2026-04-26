import processing.core.PApplet;

import java.util.HashMap;
import java.util.concurrent.ConcurrentHashMap;

public class GameApp extends PApplet {

    GameClient client;
    String username = "Player1";

    int myPlayerId = -1;

    class PlayerData {
        int id; float x, y, angle, radius;
        public PlayerData(int id, float x, float y, float angle, float mass) {
            this.id = id; this.x = x; this.y = y; this.angle = angle;
            this.radius = (float)(Math.sqrt(mass / Math.PI)) * 10;
        }
    }

    ConcurrentHashMap<Integer, PlayerData> players = new ConcurrentHashMap<>();


    // Input Flags
    int leftPressed = 0;
    int rightPressed = 0;
    int forwardPressed = 0;

    public static void main(String[] args) {
        PApplet.main("GameApp");
    }

    public void settings() {
        size(1000, 1000); // Made the window a bit bigger
    }

    public void setup() {
        client = new GameClient(this);
        client.connect("localhost", 8080);

        // Let's test the new Auth Protocol!
        String myUser = "Player1";
        String myPass = "secret123";

        // 1. Try to register
        client.sendAuthAction(1, myUser, myPass);

        // 2. Try to log in and queue
        client.sendAuthAction(2, myUser, myPass);
    }

    public void setMyPlayerId(int id) {
        this.myPlayerId = id;
    }

    public void clearPlayers() {
        players.clear();
    }

    public void updatePlayer(int id, float x, float y, float angle, float mass, int score) {
        players.put(id, new PlayerData(id, x, y, angle, mass));
    }

    public void draw() {
        background(255, 255, 255);

        // Loop through all players in the map
        for (PlayerData p : players.values()) {
            pushMatrix();
            translate(p.x, p.y);
            rotate(p.angle);

            fill(0); // Black body

            // Draw Blue border for us, Red for enemies
            if (p.id == myPlayerId) {
                stroke(0, 0, 255);
            } else {
                stroke(255, 0, 0);
            }

            strokeWeight(3);
            circle(0, 0, p.radius * 2);

            stroke(255, 0, 0); // Red direction line
            line(0, 0, p.radius, 0);
            popMatrix();
        }
    }

    public void keyPressed() {
        boolean changed = false;
        if (keyCode == LEFT && leftPressed == 0)  { leftPressed = 1; changed = true; }
        if (keyCode == RIGHT && rightPressed == 0) { rightPressed = 1; changed = true; }
        if (keyCode == UP && forwardPressed == 0)    { forwardPressed = 1; changed = true; }

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