import tkinter as tk
from tkinter import messagebox, ttk
import serial


class BUU_Horizontal_Dashboard:
    def __init__(self, root):
        self.root = root
        self.root.title("BUÜ Otonom Araç - Pro Dashboard Landscape")
        self.root.geometry("950x550")
        self.root.configure(bg="#050a18")
        self.root.resizable(False, False)

        self.ser = None
        self.pressed_keys = set()
        self.current_mode = "M"
        self.speed_level = 5

        header = tk.Frame(root, bg="#0f172a", pady=15)
        header.pack(fill="x")

        tk.Label(
            header,
            text="BURSA ULUDAĞ ÜNİVERSİTESİ",
            font=("Helvetica", 9, "bold"),
            bg="#0f172a",
            fg="#6366f1"
        ).pack()

        tk.Label(
            header,
            text="Doğrusal Hat İzleyen Otonom Araç",
            font=("Arial", 18, "bold"),
            bg="#0f172a",
            fg="#ffffff"
        ).pack(pady=2)

        main_body = tk.Frame(root, bg="#050a18", padx=20, pady=30)
        main_body.pack(fill="both", expand=True)

        left_side = tk.Frame(main_body, bg="#050a18")
        left_side.pack(side="left", fill="both", expand=True)

        conn_box = tk.LabelFrame(
            left_side,
            text=" BAĞLANTI ",
            bg="#050a18",
            fg="#6366f1",
            font=("Arial", 9, "bold"),
            padx=15,
            pady=15
        )
        conn_box.pack(fill="x", pady=(0, 20))

        self.port_entry = tk.Entry(
            conn_box,
            width=12,
            font=("Consolas", 12),
            bg="#1e293b",
            fg="white",
            borderwidth=0,
            justify="center",
            insertbackground="white"
        )
        self.port_entry.insert(0, "COM5")
        self.port_entry.pack(pady=10)

        self.btn_conn = tk.Button(
            conn_box,
            text="BAĞLAN",
            command=self.toggle_conn,
            bg="#10b981",
            fg="white",
            font=("Arial", 9, "bold"),
            relief="flat",
            height=2
        )
        self.btn_conn.pack(fill="x")

        speed_box = tk.LabelFrame(
            left_side,
            text=" HIZ KONTROLÜ ",
            bg="#050a18",
            fg="#6366f1",
            font=("Arial", 9, "bold"),
            padx=15,
            pady=15
        )
        speed_box.pack(fill="x")

        self.canvas_speed = tk.Canvas(
            speed_box,
            width=180,
            height=90,
            bg="#050a18",
            highlightthickness=0
        )
        self.canvas_speed.pack()

        self.draw_gauge(self.speed_level)

        self.speed_slider = ttk.Scale(
            speed_box,
            from_=0,
            to=9,
            orient="horizontal",
            command=self.update_speed
        )
        self.speed_slider.set(self.speed_level)
        self.speed_slider.pack(fill="x", pady=5)

        center_side = tk.Frame(main_body, bg="#050a18")
        center_side.pack(side="left", fill="both", expand=True, padx=40)

        keys_container = tk.Frame(center_side, bg="#050a18")
        keys_container.pack(expand=True)

        k_btn = {
            "width": 6,
            "height": 2,
            "font": ("Arial", 20, "bold"),
            "relief": "flat",
            "fg": "white"
        }

        self.ui_keys = {
            "w": tk.Button(keys_container, text="W", bg="#1e293b", **k_btn),
            "a": tk.Button(keys_container, text="A", bg="#1e293b", **k_btn),
            "s": tk.Button(keys_container, text="S", bg="#1e293b", **k_btn),
            "d": tk.Button(keys_container, text="D", bg="#1e293b", **k_btn)
        }

        self.ui_keys["w"].grid(row=0, column=1, pady=5)
        self.ui_keys["a"].grid(row=1, column=0, padx=5)
        self.ui_keys["s"].grid(row=1, column=1)
        self.ui_keys["d"].grid(row=1, column=2, padx=5)

        right_side = tk.Frame(main_body, bg="#050a18")
        right_side.pack(side="left", fill="both", expand=True)

        mode_box = tk.LabelFrame(
            right_side,
            text=" SÜRÜŞ MODU ",
            bg="#050a18",
            fg="#6366f1",
            font=("Arial", 9, "bold"),
            padx=15,
            pady=15
        )
        mode_box.pack(fill="x", pady=20)

        self.btn_auto = tk.Button(
            mode_box,
            text="OTOMATİK MOD",
            command=self.set_auto,
            bg="#1e293b",
            fg="white",
            font=("Arial", 10, "bold"),
            height=3,
            relief="flat"
        )
        self.btn_auto.pack(fill="x", pady=5)

        self.btn_manual = tk.Button(
            mode_box,
            text="MANUEL MOD",
            command=self.set_manual,
            bg="#f59e0b",
            fg="white",
            font=("Arial", 10, "bold"),
            height=3,
            relief="flat"
        )
        self.btn_manual.pack(fill="x", pady=5)

        distance_box = tk.LabelFrame(
            right_side,
            text=" MESAFE ",
            bg="#050a18",
            fg="#6366f1",
            font=("Arial", 9, "bold"),
            padx=15,
            pady=15
        )
        distance_box.pack(fill="x", pady=10)

        self.distance_label = tk.Label(
            distance_box,
            text="--- cm",
            bg="#050a18",
            fg="white",
            font=("Arial", 26, "bold")
        )
        self.distance_label.pack(pady=5)

        self.distance_status = tk.Label(
            distance_box,
            text="Veri bekleniyor",
            bg="#050a18",
            fg="#94a3b8",
            font=("Arial", 9, "bold")
        )
        self.distance_status.pack()

        self.status_bar = tk.Label(
            root,
            text="Sistem Hazır",
            bd=0,
            bg="#0f172a",
            fg="#94a3b8",
            font=("Arial", 8),
            pady=10
        )
        self.status_bar.pack(side="bottom", fill="x")

        self.root.bind("<KeyPress>", self.key_press)
        self.root.bind("<KeyRelease>", self.key_release)
        self.root.bind("<space>", lambda e: self.send_cmd("S"))

        self.root.after(100, self.read_serial)
        self.root.focus_set()

    def pwm_from_level(self, value):
        return int(90 + (value / 9) * (180 - 90))

    def draw_gauge(self, value):
        self.canvas_speed.delete("all")

        pwm_value = self.pwm_from_level(value)

        self.canvas_speed.create_arc(
            20,
            20,
            160,
            160,
            start=0,
            extent=180,
            outline="#1e293b",
            width=10,
            style="arc"
        )

        extent = (value / 9) * 180

        self.canvas_speed.create_arc(
            20,
            20,
            160,
            160,
            start=180,
            extent=-extent,
            outline="#6366f1",
            width=10,
            style="arc"
        )

        self.canvas_speed.create_text(
            90,
            58,
            text=f"PWM {pwm_value}",
            fill="white",
            font=("Arial", 11, "bold")
        )

        self.canvas_speed.create_text(
            90,
            76,
            text=f"Seviye {int(value)}",
            fill="#94a3b8",
            font=("Arial", 8, "bold")
        )

    def update_speed(self, event):
        val = int(float(self.speed_slider.get()))
        self.speed_level = val
        self.draw_gauge(val)
        self.send_cmd(str(val))
        self.status_bar.config(
            text=f"Hız Seviyesi: {val} | PWM: {self.pwm_from_level(val)}",
            fg="#94a3b8"
        )

    def key_press(self, event):
        k = event.keysym.lower()

        if k in ["w", "a", "s", "d"] and self.current_mode == "M":
            if k not in self.pressed_keys:
                self.pressed_keys.add(k)
                self.move()

    def key_release(self, event):
        k = event.keysym.lower()

        if k in self.pressed_keys:
            self.pressed_keys.remove(k)
            self.move()

    def move(self):
        for k, btn in self.ui_keys.items():
            btn.config(bg="#6366f1" if k in self.pressed_keys else "#1e293b")

        if "w" in self.pressed_keys and "d" in self.pressed_keys:
            self.send_cmd("G")
        elif "w" in self.pressed_keys and "a" in self.pressed_keys:
            self.send_cmd("I")
        elif "w" in self.pressed_keys:
            self.send_cmd("F")
        elif "s" in self.pressed_keys:
            self.send_cmd("B")
        elif "a" in self.pressed_keys:
            self.send_cmd("L")
        elif "d" in self.pressed_keys:
            self.send_cmd("R")
        else:
            self.send_cmd("S")

    def toggle_conn(self):
        if not self.ser:
            try:
                self.ser = serial.Serial(self.port_entry.get(), 9600, timeout=0.1)
                self.btn_conn.config(text="KES", bg="#ef4444")
                self.status_bar.config(text=f"Bağlandı: {self.port_entry.get()}", fg="#10b981")
                self.set_manual()
                self.send_cmd(str(self.speed_level))
            except:
                messagebox.showerror("Hata", "Port bulunamadı!")
        else:
            self.ser.close()
            self.ser = None
            self.btn_conn.config(text="BAĞLAN", bg="#10b981")
            self.status_bar.config(text="Bağlantı Kesildi", fg="#ef4444")
            self.distance_label.config(text="--- cm")
            self.distance_status.config(text="Veri bekleniyor", fg="#94a3b8")

    def set_auto(self):
        self.current_mode = "A"
        self.send_cmd("A")
        self.btn_auto.config(bg="#10b981")
        self.btn_manual.config(bg="#1e293b")
        self.status_bar.config(text="Mod: Otomatik", fg="#10b981")

    def set_manual(self):
        self.current_mode = "M"
        self.send_cmd("M")
        self.btn_manual.config(bg="#f59e0b")
        self.btn_auto.config(bg="#1e293b")
        self.status_bar.config(text="Mod: Manuel", fg="#f59e0b")

    def read_serial(self):
        if self.ser and self.ser.is_open:
            try:
                while self.ser.in_waiting:
                    data = self.ser.readline().decode(errors="ignore").strip()

                    if data.startswith("D:"):
                        value = data.replace("D:", "")
                        
                        try:
                            distance = float(value)

                            if distance >= 999.0:
                                self.distance_label.config(text="--- cm")
                                self.distance_status.config(text="Veri yok", fg="#94a3b8")
                            else:
                                self.distance_label.config(text=f"{distance:.2f} cm")

                                if distance <= 15.0:
                                    self.distance_status.config(text="ENGEL ALGILANDI", fg="#ef4444")
                                elif distance <= 30.0:
                                    self.distance_status.config(text="Yakın mesafe", fg="#f59e0b")
                                else:
                                    self.distance_status.config(text="Güvenli", fg="#10b981")
                        except ValueError:
                            pass
            except:
                pass

        self.root.after(100, self.read_serial)

    def send_cmd(self, char):
        if self.ser and self.ser.is_open:
            self.ser.write(char.encode())


if __name__ == "__main__":
    root = tk.Tk()
    style = ttk.Style()
    style.theme_use("clam")
    style.configure("Horizontal.TScale", background="#050a18", troughcolor="#1e293b")
    app = BUU_Horizontal_Dashboard(root)
    root.mainloop()