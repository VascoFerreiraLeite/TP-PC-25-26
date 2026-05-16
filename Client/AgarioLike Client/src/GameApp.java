import processing.core.PApplet;
import java.util.concurrent.ConcurrentHashMap;
import java.util.List;
import java.util.ArrayList;

public class GameApp extends PApplet {

    GameClient client;
    private int currentScreen = 0;

    private String endScreenWinner = "";
    private int endScreenScore = 0;
    private boolean iWon = false;

    // Função chamada quando o pacote de fim de jogo chega
    public synchronized void setMatchEnd(String winner, int score) {
        this.endScreenWinner = winner;
        this.endScreenScore = score;
        this.iWon = usernameInput.equals(winner);
        this.currentScreen = 2; // 2 = Novo Ecrã de Fim de Jogo!
    }

    private int myPlayerId = -1;
    private List<String> leaderboard = new ArrayList<>();
    private String authMessage = "";

    public synchronized void setAuthStatus(boolean success, String message) {
        this.authMessage = message;
        if (success && message.contains("Login")) {
            this.currentScreen = 1;
        }
    }

    public synchronized String getAuthMessage() { return this.authMessage; }
    public synchronized int getCurrentScreen() { return this.currentScreen; }

    public synchronized void setMyPlayerId(int id) { this.myPlayerId = id; }
    public synchronized int getMyPlayerId() { return this.myPlayerId; }

    public synchronized void updateLeaderboard(List<String> newBoard) {
        this.leaderboard = new ArrayList<>(newBoard);
    }

    public synchronized List<String> getLeaderboard() {
        return new ArrayList<>(this.leaderboard);
    }

    // ==========================================
    // CLASSES DE DADOS (Faltavam aqui)
    // ==========================================
    public class PlayerData {
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

    String usernameInput = "";
    String passwordInput = "";
    String ipInput = "localhost";
    int activeField = 1; // 0 = IP, 1 = User, 2 = Pass
    boolean isConnected = false;
    int leftPressed = 0, rightPressed = 0, forwardPressed = 0;

    ConcurrentHashMap<Integer, OrbData> orbs = new ConcurrentHashMap<>();
    ConcurrentHashMap<Integer, PlayerData> players = new ConcurrentHashMap<>();

    // Funções chamadas pelo GameClient para atualizar dados
    public synchronized void updateObjects(ConcurrentHashMap<Integer, OrbData> newOrbs) {
        this.orbs = newOrbs;
    }

    public void updatePlayer(int id, float x, float y, float angle, float mass, int score) {
        // ConcurrentHashMap já é thread-safe para puts
        players.put(id, new PlayerData(id, x, y, angle, mass, score));
    }

    public void settings() {
        size(1280, 720);
    }

    public void setup() {}

    public void draw() {
        if (getCurrentScreen() == 0) {
            drawAuthScreen();
        }
        else if(getCurrentScreen()==1) {
            drawGameScreen();
        }
        else if(getCurrentScreen()==2) {
            drawEndScreen();
        }
    }

    private void drawAuthScreen() {
        background(240);
        textAlign(CENTER, CENTER);
        fill(0);
        textSize(30);
        text("Jogo Concorrente - Autenticação", width/2, height/2 - 300);

        String msg = getAuthMessage();
        if (!msg.isEmpty()) {
            textSize(16);
            fill(255, 0, 0);
            text(msg, width/2, height/2 - 200);
        }

        stroke(0); fill(activeField == 0 ? 255 : 220);
        rect(width/2 - 100, height/2 - 140, 200, 40);
        fill(0); textSize(18);
        text("IP: " + ipInput + (activeField == 0 ? "|" : ""), width/2, height/2 - 120);

        stroke(0); fill(activeField==1 ? 255 : 220);
        rect(width/2 - 100, height/2 - 80, 200, 40);
        fill(0); textSize(18);
        text("User: " + usernameInput + (activeField==1 ? "|" : ""), width/2, height/2 - 60);

        fill(activeField==2 ? 255 : 220);
        rect(width/2 - 100, height/2 - 20, 200, 40);
        fill(0);
        String hiddenPass = new String(new char[passwordInput.length()]).replace("\0", "*");
        text("Pass: " + hiddenPass + (activeField==2 ? "|" : ""), width/2, height/2);

        fill(150, 255, 150); rect(width/2 - 150, height/2 + 50, 90, 40); fill(0); text("Login", width/2 - 105, height/2 + 70);
        fill(150, 150, 255); rect(width/2 - 45, height/2 + 50, 90, 40); fill(0); text("Registar", width/2, height/2 + 70);
        fill(255, 150, 150); rect(width/2 + 60, height/2 + 50, 110, 40); fill(0); text("Cancelar", width/2 + 115, height/2 + 70);
    }

    private void drawGameScreen() {
        background(255);
        int id = getMyPlayerId();

        if (id == -1) {
            fill(0); textAlign(CENTER, CENTER); textSize(30);
            text("WAITING FOR PLAYERS...", width/2, height/2 - 100);

            textSize(20);
            text("--- TOP SCORES ---", width/2, height/2 - 40);

            int yOffset = 0;
            List<String> board = getLeaderboard();
            for (String entry : board) {
                text(entry, width/2, height/2 + yOffset);
                yOffset += 30;
            }
            return;
        }

        // Desenhar Objetos
        for (OrbData orb : orbs.values()) {
            if (orb.type == 1) fill(0, 255, 0);
            else fill(255, 0, 0);

            noStroke();
            circle(orb.x, orb.y, orb.radius * 2);
        }

        // Desenhar Jogadores
        // Obter os jogadores e ordená-los pelo tamanho (do menor para o maior)
        List<PlayerData> sortedPlayers = new ArrayList<>(players.values());
        sortedPlayers.sort((p1, p2) -> Float.compare(p1.radius, p2.radius));

        for (PlayerData p : sortedPlayers) {
            pushMatrix();
            translate(p.x, p.y);

            rotate(p.angle);
            fill(0);
            if (p.id == id) stroke(0, 0, 255);
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

    private void drawEndScreen() {
        boolean isTie = endScreenWinner.equals("TIE");
        if (isTie) background(200);
        else if (iWon) background(200, 255, 200);
        else background(255, 200, 200);
        fill(0); textAlign(CENTER, CENTER);


        textSize(50);
        if (isTie) text("EMPATE", width/2, height/2 - 100);
        else if (iWon) text("VITÓRIA", width/2, height/2 - 100);
        else text("DERROTA", width/2, height/2 - 100);

        textSize(24);
        if (endScreenWinner.equals("TIE")) {
            text("Ocorreu um EMPATE, partida não conta.", width/2, height/2 - 20);
        } else {
            text("Vencedor: " + endScreenWinner + " com " + endScreenScore + " capturas.", width/2, height/2 - 20);
        }

        // Desenhar Botão Jogar Novamente
        fill(200); stroke(0); rect(width/2 - 100, height/2 + 50, 200, 50);
        fill(0); textSize(20); text("Voltar à Fila", width/2, height/2 + 75);
    }

    public void keyPressed() {
        if (getCurrentScreen() == 0) {
            if (key == BACKSPACE) {
                if (activeField == 0 && ipInput.length() > 0) ipInput = ipInput.substring(0, ipInput.length() - 1);
                else if (activeField == 1 && usernameInput.length() > 0) usernameInput = usernameInput.substring(0, usernameInput.length() - 1);
                else if (activeField == 2 && passwordInput.length() > 0) passwordInput = passwordInput.substring(0, passwordInput.length() - 1);
            } else if (key == TAB) {
                activeField = (activeField + 1) % 3; // Roda entre IP, User e Pass
            } else if (key >= 32 && key <= 126) {
                if (activeField == 0) ipInput += key;
                else if (activeField == 1) usernameInput += key;
                else passwordInput += key;
            }
        } else {
            boolean changed = false;
            if (keyCode == LEFT && leftPressed == 0)  { leftPressed = 1; changed = true; }
            if (keyCode == RIGHT && rightPressed == 0) { rightPressed = 1; changed = true; }
            if (keyCode == UP && forwardPressed == 0)    { forwardPressed = 1; changed = true; }
            if (changed) client.sendMovement(leftPressed, rightPressed, forwardPressed);
        }
    }

    public void keyReleased() {
        if (getCurrentScreen() == 1) {
            boolean changed = false;
            if (keyCode == LEFT)  { leftPressed = 0; changed = true; }
            if (keyCode == RIGHT) { rightPressed = 0; changed = true; }
            if (keyCode == UP)    { forwardPressed = 0; changed = true; }
            if (changed) client.sendMovement(leftPressed, rightPressed, forwardPressed);
        }
    }

    public void mousePressed() {
        if (getCurrentScreen() == 0) {
            if (mouseX > width/2 - 100 && mouseX < width/2 + 100 && mouseY > height/2 - 140 && mouseY < height/2 - 100) activeField = 0;
            else if (mouseX > width/2 - 100 && mouseX < width/2 + 100 && mouseY > height/2 - 80 && mouseY < height/2 - 40) activeField = 1;
            else if (mouseX > width/2 - 100 && mouseX < width/2 + 100 && mouseY > height/2 - 20 && mouseY < height/2 + 20) activeField = 2;

            else if (mouseX > width/2 - 150 && mouseX < width/2 - 60 && mouseY > height/2 + 50 && mouseY < height/2 + 90) connectAndSend(2); // Login
            else if (mouseX > width/2 - 45 && mouseX < width/2 + 45 && mouseY > height/2 + 50 && mouseY < height/2 + 90) connectAndSend(1); // Registar
            else if (mouseX > width/2 + 60 && mouseX < width/2 + 170 && mouseY > height/2 + 50 && mouseY < height/2 + 90) connectAndSend(3); // Cancelar
        }
        else if (getCurrentScreen() == 2) {
            // Clicou no botão "Voltar à Fila"
            if (mouseX > width / 2 - 100 && mouseX < width / 2 + 100 && mouseY > height / 2 + 50 && mouseY < height / 2 + 100) {
                // Reset ao estado local
                this.myPlayerId = -1;
                this.orbs.clear();
                this.players.clear();
                this.currentScreen = 0;
                this.isConnected = false;
                connectAndSend(2);
            }
        }
    }

    private void connectAndSend(int action) {
        if (!isConnected) {
            try {
                client = new GameClient(this);
                client.connect(ipInput, 8080);
                isConnected = true;
            } catch (Exception e) {
                setAuthStatus(false, "Erro ao ligar ao IP: " + ipInput);
                return;
            }
        }
        try {
            client.sendAuthAction(action, usernameInput, passwordInput);
        } catch (Exception e) {
            isConnected = false;
            setAuthStatus(false, "Erro de comunicação com o servidor.");
        }
    }

    public static void main(String[] args) {
        PApplet.main("GameApp");
    }
}