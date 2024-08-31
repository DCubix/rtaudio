package br.com.teknetsys.rtaudio;

public class AudioDevice {
    private final int id;
    private final String name;

    public AudioDevice(int id, String name) {
        this.id = id;
        this.name = name;
    }

    public int getId() {
        return id;
    }

    public String getName() {
        return name;
    }
}
