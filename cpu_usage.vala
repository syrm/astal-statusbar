public class CpuUsage : GLib.Object {
    // Structure pour stocker les données CPU
    private struct CpuData {
        public int64 user;
        public int64 nice;
        public int64 system;
        public int64 idle;
        public int64 iowait;
        public int64 irq;
        public int64 softirq;
        public int64 steal;
        public int64 guest;
        public int64 guest_nice;
        
        public int64 get_total() {
            return user + nice + system + idle + iowait + irq + softirq + steal + guest + guest_nice;
        }
        
        public int64 get_idle() {
            return idle + iowait;
        }
    }
    
    // Stocker les valeurs précédentes
    private CpuData prev_data;
    private bool initialized = false;
    
    public CpuUsage() {
        // Initialiser avec les premières valeurs
        prev_data = read_cpu_data();
        initialized = true;
    }
    
    // Obtenir l'utilisation CPU en pourcentage sans attente
    public double get_usage() {
        if (!initialized) {
            return 0.0;
        }
        
        // Lire les nouvelles données
        CpuData current_data = read_cpu_data();
        
        // Calculer les différences
        int64 idle_diff = current_data.get_idle() - prev_data.get_idle();
        int64 total_diff = current_data.get_total() - prev_data.get_total();
        
        // Stocker les nouvelles données pour la prochaine fois
        prev_data = current_data;
        
        if (total_diff == 0) {
            return 0.0;
        }
        
        // Calculer le pourcentage d'utilisation CPU
        return ((total_diff - idle_diff) * 100.0) / total_diff;
    }
    
    // Lire les données CPU depuis /proc/stat
    private CpuData read_cpu_data() {
        CpuData data = {};
        
        try {
            string content;
            FileUtils.get_contents("/proc/stat", out content);
            
            // Analyser la première ligne (total CPU)
            string[] lines = content.split("\n");
            foreach (string line in lines) {
                if (line.has_prefix("cpu ")) {
                    string[] parts = line.split(" ");
                    
                    // Ignorer les entrées vides (plusieurs espaces)
                    int index = 0;
                    for (int i = 1; i < parts.length; i++) {
                        if (parts[i].strip() == "") {
                            continue;
                        }
                        
                        int64 val = int64.parse(parts[i]);
                        
                        switch (index) {
                            case 0: data.user = val; break;
                            case 1: data.nice = val; break;
                            case 2: data.system = val; break;
                            case 3: data.idle = val; break;
                            case 4: data.iowait = val; break;
                            case 5: data.irq = val; break;
                            case 6: data.softirq = val; break;
                            case 7: data.steal = val; break;
                            case 8: data.guest = val; break;
                            case 9: data.guest_nice = val; break;
                        }
                        
                        index++;
                        if (index >= 10) break;
                    }
                    
                    break; // On n'a besoin que de la première ligne cpu
                }
            }
        } catch (Error e) {
            stderr.printf("Erreur lors de la lecture de /proc/stat: %s\n", e.message);
        }
        
        return data;
    }
}
