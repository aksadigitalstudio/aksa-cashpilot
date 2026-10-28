import {createClient} from 'npm:@supabase/supabase-js@2.117.2';
import {executeCommand,restrictView,validateState,publicDocument} from '../_shared/domain.js';
const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
const allowed=(Deno.env.get('CASHPILOT_ALLOWED_ORIGINS')||'http://127.0.0.1:4600').split(',').map(x=>x.trim()).filter(Boolean);
const bucket='cashpilot-documents';
function stripURLs(value:any){if(!value||typeof value!=='object')return;if(value.data?.startsWith('storage:'))delete value.url;for(const x of Object.values(value))stripURLs(x);}
async function hydrate(value:any){if(!value||typeof value!=='object')return;if(value.data?.startsWith('storage:')){const{data,error}=await admin.storage.from(bucket).createSignedUrl(value.data.slice(8),3600);if(!error)value.url=data?.signedUrl||'';}await Promise.all(Object.values(value).filter(x=>typeof x==='object').map(hydrate));}
async function uploadNew(value:any,uploaded:string[],cache:Map<string,string>){if(!value||typeof value!=='object')return;if(typeof value.data==='string'&&value.data.startsWith('data:')){const match=value.data.match(/^data:(image\/(?:jpeg|png|webp)|application\/pdf);base64,([A-Za-z0-9+/=]+)$/);if(!match)throw Error('Unsupported document format.');let path=cache.get(value.data);if(!path){const bytes=Uint8Array.from(atob(match[2]),c=>c.charCodeAt(0));if(bytes.length>2097152)throw Error('Document exceeds 2 MB.');path='objects/'+crypto.randomUUID()+'.'+match[1].split('/')[1];const{error}=await admin.storage.from(bucket).upload(path,bytes,{contentType:match[1],upsert:false});if(error)throw error;uploaded.push(path);cache.set(value.data,path);}value.data='storage:'+path;delete value.url;}for(const x of Object.values(value))await uploadNew(x,uploaded,cache);}
Deno.serve(async(req:Request)=>{
 const origin=req.headers.get('origin')||'',headers={'Access-Control-Allow-Origin':allowed.includes(origin)?origin:allowed[0]||'null','Access-Control-Allow-Headers':'authorization,x-client-info,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS','Vary':'Origin','Content-Type':'application/json','Cache-Control':'no-store'};
 const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
 if(req.method==='OPTIONS')return new Response('ok',{headers});
 if(origin&&!allowed.includes(origin))return json({error:'This origin is not authorized.'},403);
 if(req.method!=='POST')return json({error:'POST required.'},405);
 let uploaded:string[]=[];
 try{
  const raw=await req.text();if(raw.length>3_500_000)return json({error:'Request is too large.'},413);const body=JSON.parse(raw);
  if(body.action==='publicDocument'){
   if(!['invoice','receipt'].includes(body.kind)||!/^[0-9a-f-]{36}$/i.test(body.token||''))return json({error:'Document unavailable.'},404);
   const{data:state,error}=await admin.rpc('cashpilot_read');if(error)throw error;
   try{const document=publicDocument(state,body.kind,body.token);await hydrate(document.business?.logo);return json({document});}catch{return json({error:'Document unavailable.'},404);}
  }
  const jwt=(req.headers.get('authorization')||'').replace(/^Bearer\s+/i,'');
  const{data:user,error:authError}=await admin.auth.getUser(jwt);if(authError||!user.user)return json({error:'Sign in with an authorized business account.'},401);
  const{data:actor,error:profileError}=await admin.rpc('cashpilot_profile',{p_user:user.user.id});if(profileError||!actor)return json({error:'An active business staff profile is required.'},403);
  if(!['read','command'].includes(body.action))return json({error:'Unsupported action.'},400);
  if(body.action==='command'&&(!body.command||typeof body.command.id!=='string'||body.command.id.length>100||JSON.stringify(body.command).length>3_000_000))return json({error:'Invalid financial command.'},400);
  stripURLs(body.command);
  for(let attempt=0;attempt<4;attempt++){
   const{data:current,error:readError}=await admin.rpc('cashpilot_read');if(readError)throw readError;validateState(current);
   const next=body.action==='command'?executeCommand(current,body.command,actor):current;
   if(next!==current){
    await uploadNew(next,uploaded,new Map());
    const{error}=await admin.rpc('cashpilot_commit',{p_state:next,p_expected:current.revision});
    if(error){if(uploaded.length)await admin.storage.from(bucket).remove(uploaded);uploaded=[];if(error.message.includes('WORKSPACE_CONFLICT')&&attempt<3)continue;throw error;}
   }
   // Hydration happens only after server-side role filtering. Browser-supplied identity is never trusted.
   const state=restrictView(next,actor);await hydrate(state);return json({state,actor});
  }
  return json({error:'Workspace is busy. Refresh and retry.'},409);
 }catch(e){if(uploaded.length)await admin.storage.from(bucket).remove(uploaded);console.error('CashPilot operation rejected',e instanceof Error?e.message:'Unknown operation');return json({error:e instanceof Error?e.message:'Financial operation failed.'},400);}
});
