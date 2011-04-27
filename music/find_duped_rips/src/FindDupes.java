import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.Date;
import java.util.Hashtable;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

import org.jaudiotagger.audio.AudioFile;
import org.jaudiotagger.audio.AudioFileFilter;
import org.jaudiotagger.audio.AudioFileIO;

public class FindDupes {
	private File[] dirs;
	private Hashtable<String, String> tracks;

	public FindDupes(File[] dirs) {
		this.dirs = dirs;
	}

	public void run() throws IOException {
		this.tracks = new Hashtable<String, String>();

		for (File dir : dirs) {
			write("Deduping " + dir);
			dedupe(dir);
		}
	}

	private void dedupe(File dir) throws IOException {
		if (!dir.exists()) {
			write("Skipping missing dir - " + dir);
		}

		File[] subdirs = dir.listFiles(new DirectoryFilter());
		int count = 0;
		for (File subdir : subdirs) {
			dedupe(subdir);

			if (++count % 100 == 0) {
				// write("Done " + count + " of " + subdirs.length);
			}
		}

		List<AudioFile> files = getAudioFiles(dir);
		dedupe(files);
	}

	private void dedupe(List<AudioFile> files) throws IOException {
		ArrayList<AudioFile> dupes = new ArrayList<AudioFile>();
		for (AudioFile f : files) {
			if (isDupe(f)) {
				dupes.add(f);
			}
		}

		if (files.size() > 0) {
			if (dupes.size() == files.size()) {
				File parent = files.get(0).getFile().getParentFile();
				write("Whole dir of dupes: " + parent.getCanonicalPath());

				if (promptYN("Delete? [Y/n]")) {
					deltree(parent);
				}
			}
			else {
				for (AudioFile f : dupes) {
					System.out.println("");
					write("Dupe: " + f.getFile().getCanonicalPath());
					write("Orig: " + tracks.get(getTrackString(f)));
					System.out.println("");
				}
			}
		}
	}

	private void deltree(File parent) {
		for (File f : parent.listFiles()) {
			if (f.isDirectory()) {
				deltree(f);
			}
			else {
				f.delete();
			}
		}

		parent.delete();
	}

	private boolean promptYN(String string) throws IOException {
		System.out.print(string);

		BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
		String line = in.readLine();
		// in.close();

		return !line.toLowerCase().trim().equals("n");
	}

	/**
	 * Does a basic check to see if the given file is a dupe.
	 * 
	 * @throws IOException
	 */
	private boolean isDupe(AudioFile f) throws IOException {
		String track = getTrackString(f);

		if (track.trim().length() == 0) {
			write("Missing tags: " + f.getFile().getCanonicalPath());
			return false;
		}
		else if (tracks.containsKey(track)) {
			String dupe = tracks.get(track);
			return true;
		}

		tracks.put(track, f.getFile().getCanonicalPath());
		return false;
	}

	private String getTrackString(AudioFile f) {
		String res = "";

		try {
			res += getTrackNumber(f);
			res += "\t";
			res += getArtist(f);
			res += "\t";
			res += f.getTag().getFirstTitle().toLowerCase().trim();
			res += "\t";
			res += f.getTag().getFirstAlbum().toLowerCase().trim();
		}
		catch (Exception e) {
			res = "";
		}

		return res;
	}

	private String getTrackNumber(AudioFile f) {
		String res = f.getTag().getFirstTrack().toLowerCase().trim();
		while (res.trim().length() != 0 && res.length() < 2) {
			res = "0" + res;
		}

		return res;
	}

	/**
	 * Gets the artist name for the given file. Trims leading and trailing
	 * "the"s.
	 */
	private String getArtist(AudioFile f) {
		String res = f.getTag().getFirstArtist();
		res = res.toLowerCase();
		res = res.replaceAll("^the ", "");
		res = res.replaceAll(",[ ]?the$", "");
		res = res.trim();

		return res;
	}

	/**
	 * Returns a list of audio file in the given dir
	 */
	private List<AudioFile> getAudioFiles(File dir) {
		File[] files = dir.listFiles();
		Arrays.sort(files, getFilenameSorter());
		ArrayList<AudioFile> res = new ArrayList<AudioFile>();

		for (File f : files) {
			if (isAudioFile(f)) {
				try {
					res.add(AudioFileIO.read(f));
				}
				catch (Exception e) {
					e.printStackTrace();
				}
			}
		}

		return res;
	}

	/**
	 * Returns true if the given file is an audio file supported by
	 * jaudiotagger. Returns false otherwise.
	 */
	private boolean isAudioFile(File file) {
		boolean res = false;

		if (file.exists() && !file.isDirectory()) {
			try {
				res = new AudioFileFilter().accept(file);
			}
			catch (Exception e) {
				res = false;
			}
		}
		return res;
	}

	private void write(String msg) {
		String s = new Date() + "\t" + msg;
		System.out.println(s);
	}

	/**
	 * Returns a comparator that will sort files in a sensible order
	 * 
	 * @return
	 */
	public static Comparator<File> getFilenameSorter() {
		return new Comparator<File>() {
			public int compare(File f1, File f2) {
				return f1.getName().compareTo(f2.getName());
			}
		};
	}

	public static void main(String[] args) throws IOException {
		Logger.getLogger("org.jaudiotagger").setLevel(Level.OFF);
		Logger.getLogger(" org.jaudiotagger").setLevel(Level.OFF);

		File[] dirs = new File[args.length];
		for (int i = 0; i < args.length; i++) {
			dirs[i] = new File(args[i]);
		}

		FindDupes fd = new FindDupes(dirs);
		fd.run();
	}
}
