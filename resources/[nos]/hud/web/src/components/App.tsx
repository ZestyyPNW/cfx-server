import { FC, useState } from "react";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { debugData } from "@/utils/debugData";
import { isEnvBrowser } from "@/utils/misc";
import { Vehicle } from "./Vehicle";
import { Watermark } from "./Watermark";
import { ServerStatus } from "./server";
import { type Postal as PostalType } from "@/interfaces/postal";

debugData([
  {
    action: "setVisible",
    data: true,
  },
  {
    action: "setStatuses",
    data: {
      health: 85,
      armor: 60,
      oxygen: 50,
    },
  },
  {
    action: "setInVehicle",
    data: true,
  },
  {
    action: "updateVehicle",
    data: {
      speed: 45,
      fuel: 75,
      engine: 95,
      gear: 3,
      seatbelt: false,
    },
  },
  { action: "setPostal", data: { code: "1234", dist: 50 } },
  {
    action: "setCompass",
    data: { heading: 270, street: "Main St", crossStreet: "2nd Ave" },
  },
  {
    action: "setAOP",
    data: { aop: "Los Santos", peacetime: true, priority: { enabled: true, name: "nossux" } },
  },
  {
    action: "setStreet",
    data: {
      a: "Vinewood Blvd",
      b: "Mirror Park Blvd",
      direction: "West",
      crossStreet: "Mirror Park Blvd",
    }
  },
  {
    action: "setInVehicle",
    data: {
      isInVehicle: true,
      minimap: false,
    },
  }
]);

export const App: FC = () => {
  const [visible, setVisible] = useState<boolean>(false);
  useNuiEvent<boolean>("setVisible", (isVisible: boolean) =>
    setVisible(isVisible)
  );

  const [inVehicle, setInVehicle] = useState<boolean>(false);
  useNuiEvent<{ isInVehicle: boolean; minimap: boolean }>("setInVehicle", (data) => {
    setInVehicle(data.isInVehicle);
  });

  const [postal, setPostal] = useState<PostalType | null>(
    null
  );
  useNuiEvent("setPostal", (newPostal: PostalType | null) =>
    setPostal(newPostal)
  );

  const [aop, setAop] = useState<{
    aop: string;
    peacetime: boolean;
    priority: any;
  } | null>(null);

  useNuiEvent(
    "setAOP",
    (newAOP: { aop: string; peacetime: boolean; priority: any }) => setAop(newAOP));

  return (
    <main
      style={
        isEnvBrowser()
          ? {
            backgroundImage: "url(https://i.imgur.com/uizsGzk.jpeg)",
            backgroundSize: "cover",
            width: "100vw",
            height: "100vh",
            top: 0,
            left: 0,
          }
          : {}
      }
    >
      <ServerStatus inVehicle={inVehicle} data={aop || { aop: "", peacetime: false, priority: null }} visible={visible} postal={postal || undefined} />
      <Watermark />
      <Vehicle inVehicle={inVehicle}  postal={postal || undefined} />
    </main>
  );
};
