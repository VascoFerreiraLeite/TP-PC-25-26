import processing.core.PApplet;
import java.util.concurrent.ConcurrentHashMap;

public class GameApp extends PApplet {

    GameClient client;

    int myPlayerId = -1;

    java.util.List<String> leaderboard = new java.util.ArrayList<>();

    int login = 0; //0 - login, 1 - jogo

    String inputUser = "";
    
    String inputPass = "";
    
    boolean typingUser = true; 

    public void updateLeaderboard(java.util.List<String> newBoard) {
        this.leaderboard = newBoard;
    }

    public void setMyPlayerId(int id) {
        this.myPlayerId = id;
    }

    class PlayerData {
        int id, score; float x, y, angle, radius;
        public PlayerData(int id, float x, float y, float angle, float mass, int score) {
            this.id = id; this.x = x; this.y = y; this.angle = angle; this.score = score;
            this.radius = (float)(Math.sqrt(mass / Math.PI)) * 10;
        }
    }

    public class OrbData {
        int id; float x, y, radius; byte type;
        public OrbData(int id, float x, float y, float radius, byte type) {
            this.id = id; this.x = x; this.y = y; this.radius = radius; this.type = type;
        }
    }

    ConcurrentHashMap<Integer, OrbData> orbs = new ConcurrentHashMap<>();

    public void updateObjects(ConcurrentHashMap<Integer, OrbData> newOrbs) {
        this.orbs = newOrbs;
    }

    ConcurrentHashMap<Integer, PlayerData> players = new ConcurrentHashMap<>();

    int leftPressed = 0;
    int rightPressed = 0;
    int forwardPressed = 0;

    public static void main(String[] args) {
        PApplet.main("GameApp");
    }

    public void settings() {
        size(1280, 720);
    }

    public void setup() {
        client = new GameClient(this);
        client.connect("localhost", 8080);

        String myUser = "Player1";
        String myPass = "secret123";

        client.sendAuthAction(1, myUser, myPass);

        client.sendAuthAction(2, myUser, myPass);
    }

    public void updatePlayer(int id, float x, float y, float angle, float mass, int score) {
        players.put(id, new PlayerData(id, x, y, angle, mass, score));
    }

    public void draw() {
        background(255, 255, 255);

        if (login == 0) {
            drawLoginScreen();
            return;
        }

        if (myPlayerId == -1) {
            fill(0);
            textAlign(CENTER, CENTER);
            textSize(30);
            text("WAITING FOR PLAYERS...", width/2, height/2 - 100);

            textSize(20);
            text("--- TOP SCORES ---", width/2, height/2 - 40);

            int yOffset = 0;
            for (String entry : leaderboard) {
                text(entry, width/2, height/2 + yOffset);
                yOffset += 30;
            }
            return; // Stop drawing the game room, we aren't in it yet!
        }

        for (OrbData orb : orbs.values()) {
            if (orb.type == 1) fill(0, 255, 0);
            else fill(255, 0, 0);

            noStroke();
            circle(orb.x, orb.y, orb.radius * 2);
        }


        for (PlayerData p : players.values()) {
            pushMatrix();
            translate(p.x, p.y);

            rotate(p.angle);
            fill(0);
            if (p.id == myPlayerId) stroke(0, 0, 255);
            else stroke(255, 0, 0);
            strokeWeight(3);
            circle(0, 0, p.radius * 2);
            stroke(255, 0, 0);
            line(0, 0, p.radius, 0);

            rotate(-p.angle);
            fill(255);
            textAlign(CENTER, CENTER);
            textSize(Math.max(12, p.radius / 1.5f));
            text(p.score, 0, 0);

            popMatrix();
        }


    }

    public void keyPressed() {
        if (login == 0) {
        if (key == TAB) {
            typingUser = !typingUser; 
        } else if (key == BACKSPACE) {
            if (typingUser && inputUser.length() > 0) {
                inputUser = inputUser.substring(0, inputUser.length() - 1);
            } else if (!typingUser && inputPass.length() > 0) {
                inputPass = inputPass.substring(0, inputPass.length() - 1);
            }
        } else if (key != CODED && key != ENTER && key != RETURN) {
            if (typingUser) inputUser += key;
            else inputPass += key;
        }
        return;
    }
        
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

    public void drawLoginScreen() {
        fill(0);
        textAlign(CENTER, CENTER);
        
        textSize(30);
        text("BEM-VINDO AO AGARIO-LIKE", width/2, height/2 - 150);

        textSize(20);
        text("Username: " + inputUser + (typingUser ? "_" : ""), width/2, height/2 - 80);
        text("Password: " + inputPass + (!typingUser ? "_" : ""), width/2, height/2 - 40);

        textSize(16);
        fill(100);
        text("Pressione TAB para alternar entre Username e Password", width/2, height/2 + 20);

        fill(200); rect(width/2 - 160, height/2 + 60, 100, 40);
        fill(0); text("LOGIN", width/2 - 110, height/2 + 80);

        fill(200); rect(width/2 - 40, height/2 + 60, 100, 40);
        fill(0); text("REGISTAR", width/2 + 10, height/2 + 80);

        fill(200); rect(width/2 + 80, height/2 + 60, 100, 40);
        fill(0); text("CANCELAR", width/2 + 130, height/2 + 80);
    }

    public void mousePressed() {
        if (uiState == 0) {
            int my = height/2 + 60;
            if (mouseY >= my && mouseY <= my + 40) {
                
                // Clicou no botão LOGIN
                if (mouseX >= width/2 - 160 && mouseX <= width/2 - 60) {
                    client.sendAuthAction(2, inputUser, inputPass);
                    uiState = 1; 
                } 
                else if (mouseX >= width/2 - 40 && mouseX <= width/2 + 60) {
                    client.sendAuthAction(1, inputUser, inputPass);
                } 
                else if (mouseX >= width/2 + 80 && mouseX <= width/2 + 180) {
                    client.sendAuthAction(3, inputUser, inputPass);
                }
            }
        }
    }
}